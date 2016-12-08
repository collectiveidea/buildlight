module ColorHelper
  def color_attrs_for_body(colors)
    html = ""

    if colors
      html << if colors[:red]
                " data-failing"
              else
                " data-passing"
              end

      html << " data-building" if colors[:yellow]
    end

    html
  end

  def color_favicon_link_tag(colors)
    filename = "/favicon"

    if colors
      filename << if colors[:red]
                    "-failing"
                  else
                    "-passing"
                  end

      filename << "-building" if colors[:yellow]
    end

    filename << ".ico"
    favicon_link_tag filename, id: "favicon"
  end
end
