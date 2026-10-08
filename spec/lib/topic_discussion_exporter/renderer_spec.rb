# frozen_string_literal: true

require "rails_helper"

RSpec.describe TopicDiscussionExporter::Renderer do
  let(:topic) { Fabricate(:topic, title: "Hello <World>") }
  let(:alice) { Fabricate(:user, username: "alice") }

  def sample_post(number, cooked)
    double(
      user: alice,
      created_at: Time.utc(2026, 10, 1),
      post_number: number,
      cooked: cooked,
    )
  end

  it "exports every reply, not just the initially loaded post stream" do
    posts = (1..35).map { |n| sample_post(n, "<p>Message #{n}</p>") }
    result = described_class.new(topic, posts).call
    expect(result[:post_count]).to eq(35)
    expect(result[:html]).to include("Message 1", "Message 35")
    expect(result[:text]).to include("Message 35")
  end

  it "strips forum styles and active content while retaining useful formatting" do
    cooked = <<~HTML
      <div style="background:red" class="cooked">
        <p style="background:black;color:white"><strong>Bold</strong> <em>Italic</em></p>
        <aside class="quote"><p>Quoted</p></aside>
        <a href="javascript:alert(1)" onclick="alert(1)">unsafe link</a>
        <a href="/t/other/2">internal link</a>
        <img src="/uploads/default/original/1X/example.png" onerror="alert(1)">
        <iframe src="https://example.com/"></iframe>
        <script>alert(1)</script>
      </div>
    HTML
    html = described_class.new(topic, [sample_post(1, cooked)], base_url: "https://forum.example.org").call[:html]

    expect(html).to include("<strong>Bold</strong>", "<em>Italic</em>", "<blockquote")
    expect(html).to include('href="https://forum.example.org/t/other/2"')
    expect(html).to include('src="https://forum.example.org/uploads/default/original/1X/example.png"')
    expect(html).not_to include("javascript:", "onclick", "onerror", "iframe", "<script", "background:red", "background:black")
    expect(html).to include("Hello &lt;World&gt;")
  end

  it "sets safe explicit pixel line heights on every text container" do
    cooked = <<~HTML
      <h2>Heading with long enough words for multiple lines</h2>
      <p>Text <strong>bold</strong> and <em>italic</em> before a
      <a href="/t/another/1">long link with more words</a>.</p>
      <aside class="quote"><p>Quoted paragraph across several lines.</p></aside>
      <ul><li>Long list item <strong>with emphasis</strong></li></ul>
      <table><tr><td>Cell with text</td></tr></table>
      <pre><code>example code with a long string</code></pre>
      <aside class="onebox"><a href="https://example.com">Oneboxed URL</a></aside>
    HTML

    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    doc = Nokogiri::HTML.fragment(html)
    containers = doc.css("div, section, p, h1, h2, h3, h4, ul, ol, li, blockquote, pre, table, td, th")
    expect(containers).not_to be_empty
    containers.each do |node|
      style = node["style"].to_s
      font_size = style[/font-size:(\d+)px/, 1].to_i
      line_height = style[/line-height:(\d+)px/, 1].to_i

      expect(line_height).to be >= 24, "Missing or unsafe line-height on #{node.name}: #{style}"
      expect(line_height).to be >= font_size * 1.5, "Insufficient line spacing on #{node.name}: #{style}"
    end
    expect(html).not_to match(/line-height:\d+(?:\.\d+)?;/)
    expect(html).not_to include("font-family:")
  end

  it "preserves images, tables and code without inheriting arbitrary CSS" do
    cooked = '<table><tr><td colspan="2" style="background:lime">A</td></tr></table><pre><code>if (x < 1) { y++; }</code></pre>'
    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    expect(html).to include("<table", 'colspan="2"', "if (x &lt; 1)")
    expect(html).not_to include("background:lime")
  end
end
