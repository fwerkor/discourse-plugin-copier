# frozen_string_literal: true

require "erb"
require "uri"
require "nokogiri"

module ::TopicDiscussionExporter
  class Renderer
    OMIT = %w[script style iframe object embed form button input select textarea
              canvas video audio noscript svg meta link].freeze

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

      html << %(<h1>#{escape(@topic.title)}</h1>)
      html << %(<p><a href="#{escape(topic_url)}">#{escape(topic_url)}</a></p>)

      @posts.each do |post|
        count += 1
        author = post.user&.name.presence || post.user&.username || "Deleted user"
        date = post.created_at.utc.strftime("%Y-%m-%d %H:%M UTC")
        if count > 1
          html << "<hr>"
        end
        html << %(<p><strong>#{escape(author)}</strong> · #{escape(date)} · ##{post.post_number}</p>)
        html << sanitize(post.cooked.to_s)

        text << "\n#{author} · #{date} · ##{post.post_number}\n"
        text << Nokogiri::HTML.fragment(post.cooked.to_s).text.strip
        text << "\n"
      end

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
        return href ? %(<p><a href="#{escape(href)}">#{escape(link.text.strip.presence || href)}</a></p>) : ""
      end

      children = node.children.map { |child| render_node(child) }.join
      return "<blockquote>#{children}</blockquote>" if tag == "aside" && node["class"]&.split&.include?("quote")
      return children unless TAGS.include?(tag)

      tag = "strong" if tag == "b"
      tag = "em" if tag == "i"
      attributes = +""

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
        code = escape(node.text).gsub("\r\n", "\n").gsub("\t", "    ")
        return "<p><code>#{code.gsub(" ", "&nbsp;").gsub("\n", "<br>")}</code></p>"
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
