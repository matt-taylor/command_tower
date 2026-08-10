# frozen_string_literal: true

# Shared scanners for Phase 5.7.1–5.7.4 structural test-standards guards.
module CommandTower
  module TestStandardsScanner
    module_function

    SETUP_IN_IT_RE = /
      \.(update_columns|update!|update_attribute|update_all|delete_all|destroy_all|destroy!|save!)|
      \.(update|destroy|save)\s*\(|
      \b(create|create!|build|build_stubbed|create_list)\s*\(|
      \ballow\s*\(|
      \ballow_any_instance_of\s*\(|
      \.config\.[\w.]+\s*=|
      \bstub_const\s*\(|
      \btravel_to\s*\(|
      \bfreeze_time\b|
      \bActionMailer::Base\.deliveries\.clear\b|
      \bstub_request\s*\(
    /x

    ASSIGN_IN_IT_RE = /^\s*(?:[A-Za-z_]\w*|@[A-Za-z_]\w*)\s*=(?!=)/

    def strip_heredocs(source)
      source.gsub(/<<[-~]?['"]?\w+['"]?.*?^\s*\w+\s*$/m, "")
    end

    def opens_block?(stripped)
      stripped.include?(" do") || stripped.end_with?("do") || stripped.match?(/\{\s*$/) || stripped.match?(/\bdo\s*\|/)
    end

    # Walk lines with indent + `end` stack. Yields [line_index_0, line, stripped, in_it].
    def each_example_body_line(path)
      stack = []
      File.readlines(path).each_with_index do |line, idx|
        stripped = line.strip
        next if stripped.start_with?("#")

        indent = line[/\A */].length
        if stripped.match?(/\Aend\b/)
          stack.pop while stack.any? && stack.last[0] >= indent
        else
          stack.pop while stack.any? && stack.last[0] > indent
        end

        if stripped.match?(/\A(it|specify|example)\b/) && opens_block?(stripped)
          stack << [indent, :it]
        elsif stripped.match?(/\A(before|after|around|let!?|subject|context|describe|shared_examples|shared_context|RSpec\.describe)\b/) &&
              opens_block?(stripped)
          stack << [indent, :other]
        end

        in_it = stack.any? { |_, kind| kind == :it }
        yield idx, line, stripped, in_it
      end
    end

    # Example-group `def` helpers, excluding Class.new / controller do...end bodies.
    def example_group_defs(source)
      cleaned = strip_heredocs(source)
      lines = cleaned.lines
      eg = []
      stack = []
      lines.each_with_index do |line, idx|
        stripped = line.strip
        indent = line[/\A */].length
        if stripped.match?(/Class\.new|controller\s*\(/) && stripped.match?(/\bdo\b/)
          stack << indent
          next
        end
        if stack.any? && stripped.match?(/\Aend\b/) && indent == stack.last
          stack.pop
          next
        end
        next if stack.any?

        eg << [idx + 1, stripped] if stripped.match?(/\Adef\s+/)
      end
      eg
    end

    def allow_inside_it_offenders(path)
      offenders = []
      each_example_body_line(path) do |idx, _line, stripped, in_it|
        next unless in_it
        next if stripped.match?(/\A(it|specify|example)\b/)
        next unless stripped.match?(/\ballow\s*\(/)

        offenders << "#{idx + 1}: #{stripped}"
      end
      offenders
    end

    # Skip lines inside multi-line `expect { ... }` / `change { ... }` matcher blocks.
    def each_it_line_outside_matcher_blocks(path)
      in_brace_matcher = false
      each_example_body_line(path) do |idx, _line, stripped, in_it|
        next unless in_it
        next if stripped.match?(/\A(it|specify|example)\b/)

        if in_brace_matcher
          in_brace_matcher = false if stripped.match?(/\A\}\s*\.(to|not_to|to_not)\b/) || stripped == "}"
          next
        end

        # Enter multi-line expect/change brace block when opened without closing on same line.
        if stripped.match?(/\b(expect|change)\s*\{/) && !stripped.match?(/\}\s*\.(to|not_to|to_not)\b/) && !stripped.match?(/\}\s*$/)
          in_brace_matcher = true
          next
        end

        # Single-line expect { ... }.to — skip entire line
        next if stripped.start_with?("expect") || stripped.start_with?("is_expected")
        next if stripped.match?(/\bchange\s*\{/)

        yield idx, stripped
      end
    end

    def assign_inside_it_offenders(path)
      offenders = []
      each_it_line_outside_matcher_blocks(path) do |idx, stripped|
        next unless stripped.match?(ASSIGN_IN_IT_RE)
        next if stripped.match?(/\A(let|subject|before|after)\b/)

        offenders << "#{idx + 1}: #{stripped}"
      end
      offenders
    end

    def setup_inside_it_offenders(path)
      offenders = []
      each_it_line_outside_matcher_blocks(path) do |idx, stripped|
        next unless stripped.match?(SETUP_IN_IT_RE)

        offenders << "#{idx + 1}: #{stripped}"
      end
      offenders
    end

    def bare_double_hits(path)
      File.readlines(path).each_with_index.filter_map do |line, idx|
        next if line.strip.start_with?("#")
        next unless line.match?(/\bdouble\s*\(/)
        next if line.match?(/instance_double|class_double|object_double|verify_partial_doubles/)
        next if line.strip.match?(/\A(it|specify|example)\b/)

        "#{idx + 1}:#{line.strip}"
      end
    end

    def allow_any_instance_of_hits(path)
      File.readlines(path).each_with_index.filter_map do |line, idx|
        next if line.strip.start_with?("#")
        next if line.strip.match?(/\A(it|specify|example)\b/)
        next unless line.match?(/\ballow_any_instance_of\s*\(/)

        "#{idx + 1}:#{line.strip}"
      end
    end
  end
end
