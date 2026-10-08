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

  it "exports minimal semantic HTML without editor-specific CSS" do
    cooked = <<~HTML
      <h2>Heading</h2>
      <p style="font-size:1px;line-height:0"><strong>Bold</strong> and <em>italic</em> text.</p>
      <aside class="quote"><p>Quoted paragraph</p></aside>
      <ul><li>List item</li></ul>
      <table><tr><td>Cell with text</td></tr></table>
      <pre><code>example code</code></pre>
      <aside class="onebox"><a href="https://example.com">Link preview</a></aside>
    HTML

    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    document = Nokogiri::HTML.fragment(html)

    expect(document.children.map(&:name)).to include("h1", "p", "h2", "blockquote", "ul", "table")
    expect(html).to include("<strong>Bold</strong>", "<em>italic</em>", "<blockquote>", "<li>List item</li>")
    expect(html).to include("<a href=\"https://example.com\">Link preview</a>")
    expect(html).to include("<p><code>example&nbsp;code</code></p>")
    expect(html).not_to include("<pre")
    expect(html).not_to match(/style\s*=/i)
    expect(html).not_to include("<section", "<div", "font-size", "line-height")
  end

  it "preserves indentation and newlines in code without a pre element" do
    cooked = "<pre><code>if (x) {\n  call();\n}</code></pre>"
    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    expect(html).to include("if&nbsp;(x)&nbsp;{<br>&nbsp;&nbsp;call();<br>}")
    expect(html).not_to include("<pre", "style=")
  end

  it "preserves images, tables and code without inheriting arbitrary CSS" do
    cooked = '<table><tr><td colspan="2" style="background:lime">A</td></tr></table><pre><code>if (x < 1) { y++; }</code></pre>'
    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    expect(html).to include("<table", 'colspan="2"', "if&nbsp;(x&nbsp;&lt;&nbsp;1)")
    expect(html).not_to include("background:lime")
  end
end
