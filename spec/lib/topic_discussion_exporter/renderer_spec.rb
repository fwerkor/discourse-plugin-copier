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

  it "keeps prose minimal while rendering scrollable dark code blocks by default" do
    cooked = <<~HTML
      <h2>Heading</h2>
      <p style="font-size:1px;line-height:0"><strong>Bold</strong> and <em>italic</em> text.</p>
      <aside class="quote"><p>Quoted paragraph</p></aside>
      <ul><li>List item</li></ul>
      <table><tr><td>Cell with text</td></tr></table>
      <pre><code>example code with a very long line that must not wrap</code></pre>
      <aside class="onebox"><a href="https://example.com">Link preview</a></aside>
    HTML

    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    document = Nokogiri::HTML.fragment(html)
    container = document.at_css("div[style*=overflow-x]")

    expect(container).not_to be_nil
    expect(container["style"]).to include("background-color:#161b22", "overflow-x:auto", "max-width:100%")
    expect(container.at_css("code")["style"]).to include("white-space:pre", "font-family:")
    expect(container.at_css("code").text).to include("example code with a very long line")
    expect(document.children.map(&:name)).to include("h1", "p", "h2", "blockquote", "ul", "table", "div")
    expect(html).to include("<strong>Bold</strong>", "<em>italic</em>", "<blockquote>", "<li>List item</li>")
    expect(html).to include('<a href="https://example.com">Link preview</a>')
    expect(html).not_to include("<pre", "line-height:", "font-size:")
    expect(document.css("[style]").size).to eq(2)
    expect(document.css("p[style], h1[style], h2[style], ul[style], td[style]")).to be_empty
  end

  it "preserves code indentation, newlines and syntax colors without trusting source styles" do
    cooked = <<~HTML
      <pre><code class="lang-python hljs"><span class="hljs-keyword" style="background:red">def</span> greet():
        <span class="hljs-string">"hello"</span>  # comment
      </code></pre>
    HTML
    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    code = Nokogiri::HTML.fragment(html).at_css("div > code")

    expect(code.inner_html).to include('<span style="color:#ff7b72;">def</span>')
    expect(code.css("span[style]").last.text).to eq('"hello"')
    expect(code.css("span[style]").last["style"]).to eq("color:#a5d6ff;")
    expect(code.text).to include("greet():\n", '  # comment')
    expect(html).not_to include("background:red", "class=", "<pre", "line-height:")
  end

  it "escapes unknown tokens and active content inside code" do
    cooked = '<pre><code><span style="font-size:1px" class="unknown">x</span>&lt;script&gt;alert(1)&lt;/script&gt;<img src=x onerror=alert(1)></code></pre>'
    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    expect(html).to include('x&lt;script&gt;alert(1)&lt;/script&gt;')
    expect(html).not_to include("font-size:1px", "onerror", "<img")
  end

  it "preserves images, tables and code without inheriting arbitrary CSS" do
    cooked = '<table><tr><td colspan="2" style="background:lime">A</td></tr></table><pre><code>if (x < 1) { y++; }</code></pre>'
    html = described_class.new(topic, [sample_post(1, cooked)]).call[:html]
    expect(html).to include("<table", 'colspan="2"', "if (x &lt; 1)")
    expect(html).not_to include("background:lime")
  end
end
