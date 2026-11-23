# frozen_string_literal: true

module CommandTower
  module UI
    module Email
      class Renderer
        # badge, button, image and avatar, plus link and image-source checks.
        module InlineNodes
          IMAGE_WIDTH = 552 # container 600 minus 2 x 24 padding

          private

          def badge(node)
            tag.table(tag.tr(tag.td(node.label, style: badge_style(node.tone))), **TABLE)
          end

          def button(node)
            return tag.a(node.label, href: link_href(node.action), style: small_link_style) if node.variant == "ghost"

            tag.table(tag.tr(tag.td(button_link(node), style: button_cell_style(node.variant))), **TABLE)
          end

          def button_link(node)
            tag.a(node.label, href: link_href(node.action), style: button_link_style(node.variant))
          end

          def image(node)
            check_image!(node.src)
            tag.img(src: node.src, alt: node.decorative ? "" : node.alt.to_s, width: IMAGE_WIDTH,
                    height: (IMAGE_WIDTH / node.aspect).round,
                    style: css("display" => "block", "border" => 0, "max-width" => "100%", "height" => "auto"))
          end

          def avatar(node)
            size = Tokens.avatar_px(node.size)
            return avatar_image(node, size) if node.src.present?

            cell = tag.td(node.initials.to_s, width: size, height: size, align: "center", valign: "middle",
                                              style: avatar_style(size))
            tag.table(tag.tr(cell), **TABLE)
          end

          def avatar_image(node, size)
            check_image!(node.src)
            tag.img(src: node.src, alt: node.alt.to_s, width: size, height: size,
                    style: css("display" => "block", "border" => 0, "border-radius" => "50%"))
          end

          def link_href(action)
            return @origin + action.path if action.path

            code = Hardening.external_href_code(action.href)
            reject!("link", code) if code
            action.href
          end

          def check_image!(src)
            code = Hardening.image_src_code(src, hosts: CommandTower.config.ui.image_hosts)
            reject!("image", code) if code
          end

          def reject!(path, code)
            message = "Invalid UI document: #{path}:#{code}"
            raise InvalidDocumentError.new(message, details: [{ path:, code: code.to_s }])
          end
        end
      end
    end
  end
end
