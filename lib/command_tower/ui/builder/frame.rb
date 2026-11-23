# frozen_string_literal: true

module CommandTower
  module UI
    class Builder
      # A collection of nodes under construction and where it sits in the document.
      Frame = Struct.new(:path, :kind, :nodes) do
        def next_path
          case kind
          when :root then "root"
          when :fallback then "#{path}.fallback"
          else "#{path}.children[#{nodes.length}]"
          end
        end
      end
      private_constant :Frame
    end
  end
end
