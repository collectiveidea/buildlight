module ColorHelper
  def color_attrs_for_body(colors)
    html = ""

    if colors
      if colors[:red]
        html << " data-failing"
      else
        html << " data-passing"
      end

      html << " data-building" if colors[:yellow]
    end

    html
  end

  def color_favicon_link_tag(colors)
    filename = "/favicon"

    if colors
      if colors[:red]
        filename << "-failing"
      else
        filename << "-passing"
      end

      filename << "-building" if colors[:yellow]
    end

    filename << ".ico"
    favicon_link_tag filename, id: "favicon"
  end
end
