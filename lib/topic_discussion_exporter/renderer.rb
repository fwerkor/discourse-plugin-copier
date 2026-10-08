# frozen_string_literal: true

require "erb"
require "uri"
require "nokogiri"

module ::TopicDiscussionExporter
  class Renderer
    OMIT = %w[script style iframe object embed form button input select textarea
              canvas video audio noscript svg meta link].freeze

    STYLES = {
      "p" => "font-size:16px;line-height:29px;margin:0 0 14px;",
      "h1" => "font-size:22px;line-height:36px;font-weight:700;margin:20px 0 12px;",
      "h2" => "font-size:19px;line-height:32px;font-weight:700;margin:19px 0 11px;",
      "h3" => "font-size:17px;line-height:29px;font-weight:700;margin:16px 0 9px;",
      "h4" => "font-size:16px;line-height:28px;font-weight:700;margin:14px 0 8px;",
      "ul" => "font-size:16px;line-height:29px;padding-left:24px;margin:0 0 14px;",
      "ol" => "font-size:16px;line-height:29px;padding-left:24px;margin:0 0 14px;",
      "li" => "font-size:16px;line-height:29px;margin-bottom:5px;",
      "blockquote" => "font-size:16px;line-height:29px;margin:12px 0 16px;padding:4px 0 4px 14px;border-left:3px solid #b7b7b7;color:#555;",
      "pre" => "white-space:pre-wrap;word-break:break-word;font-size:14px;line-height:26px;margin:12px 0;padding:8px 0 8px 12px;border-left:2px solid #ccc;",
      "code" => "overflow-wrap:anywhere;",
      "a" => "color:#1769aa;text-decoration:underline;",
      "img" => "max-width:100%;height:auto;display:inline-block;",
      "table" => "font-size:16px;line-height:29px;border-collapse:collapse;width:100%;margin:12px 0;",
      "td" => "font-size:16px;line-height:29px;border:1px solid #ddd;padding:6px 9px;vertical-align:top;",
      "th" => "font-size:16px;line-height:29px;border:1px solid #ddd;padding:6px 9px;font-weight:700;text-align:left;",
    }.freeze

    TAGS = %w[p br strong b em i del u s h1 h2 h3 h4 ul ol li blockquote
              pre code a img table thead tbody tr td th hr sup sub].freeze

    def initialize(topic, posts, base_url: Discourse.base_url)
      @topic = topic
      @posts = posts
      @base_url = base_url.chomp("/")
    end

    def call
      html = +""
      text = +"#{@topic.title}\n#{topic_url}\n"
      count = 0

      html << %(<div style="color:#262626;font-size:16px;line-height:29px;overflow-wrap:break-word;">)
      html << %(<h1 style="font-size:25px;line-height:40px;font-weight:700;margin:0 0 12px;">#{escape(@topic.title)}</h1>)
      html << %(<p style="color:#777;font-size:13px;line-height:24px;margin:0 0 25px;">)
      html << %(#{escape(topic_url)}</p>)

      @posts.each do |post|
        count += 1
        author = post.user&.name.presence || post.user&.username || "Deleted user"
        date = post.created_at.utc.strftime("%Y-%m-%d %H:%M UTC")
        html << %(<section style="font-size:16px;line-height:29px;margin:0 0 25px;">)
        if count > 1
          html << %(<hr style="border:0;border-top:1px solid #e5e5e5;margin:25px 0 15px;">)
        end
        html << %(<p style="color:#777;font-size:13px;line-height:24px;margin:0 0 12px;">)
        html << %(<strong style="color:#333;">#{escape(author)}</strong> · #{escape(date)} · ##{post.post_number}</p>)
        html << sanitize(post.cooked.to_s)
        html << %(</section>)

        text << "\n#{author} · #{date} · ##{post.post_number}\n"
        text << Nokogiri::HTML.fragment(post.cooked.to_s).text.strip
        text << "\n"
      end

      html << %(</div>)
      { html: html, text: text.strip, post_count: count }
    end

    private

    def topic_url
      "#{@base_url}/t/#{@topic.slug}/#{@topic.id}"
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end

    def safe_url(value)
      value = value.to_s.strip
      return nil if value.empty? || value.match?(/[\x00-\x1f\x7f]/)

      if value.start_with?("/") && !value.start_with?("//")
        "#{@base_url}#{value}"
      elsif value.start_with?("//")
        "#{URI.parse(@base_url).scheme}:#{value}"
      else
        uri = URI.parse(value)
        value if %w[http https mailto].include?(uri.scheme&.downcase)
      end
    rescue URI::InvalidURIError
      nil
    end

    def sanitize(cooked)
      fragment = Nokogiri::HTML.fragment(cooked)
      fragment.children.map { |child| render_node(child) }.join
    end

    def render_node(node)
      return escape(node.text) if node.text?
      return "" unless node.element?

      tag = node.name.downcase
      return "" if OMIT.include?(tag)

      if node["class"]&.split&.include?("emoji") && tag == "img"
        return escape(node["alt"])
      end

      if node["class"]&.split&.include?("onebox")
        link = node.at_css("a[href]")
        href = safe_url(link&.[]("href"))
        return href ? %(<p style="#{STYLES["p"]}"><a style="#{STYLES["a"]}" href="#{escape(href)}">#{escape(link.text.strip.presence || href)}</a></p>) : ""
      end

      children = node.children.map { |child| render_node(child) }.join
      return %(<blockquote style="#{STYLES["blockquote"]}">#{children}</blockquote>) if tag == "aside" && node["class"]&.split&.include?("quote")
      return children unless TAGS.include?(tag)

      tag = "strong" if tag == "b"
      tag = "em" if tag == "i"
      attributes = STYLES[tag] ? %( style="#{STYLES[tag]}") : ""

      case tag
      when "a"
        href = safe_url(node["href"])
        return children unless href

        attributes << %( href="#{escape(href)}")
      when "img"
        src = safe_url(node["src"])
        return "" unless src&.start_with?("http")

        attributes << %( src="#{escape(src)}")
        attributes << %( alt="#{escape(node["alt"])}") if node["alt"]
        return "<img#{attributes}>"
      when "pre"
        return "<pre#{attributes}>#{escape(node.text)}</pre>"
      when "br", "hr"
        return "<#{tag}#{attributes}>"
      when "td", "th"
        %w[colspan rowspan].each do |key|
          val = node[key]
          attributes << %( #{key}="#{val}") if val&.match?(/\A[1-9][0-9]?\z/)
        end
      end

      "<#{tag}#{attributes}>#{children}</#{tag}>"
    end
  end
end
