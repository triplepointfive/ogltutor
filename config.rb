require "slim"

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false

# With alternative layout
# page "/path/to/file.html", layout: :otherlayout

page '/cont.html', layout: :layout
page '/instr.html', layout: :layout

page '/tutorials/*', content_type: 'text/html'

activate :relative_assets
set :relative_links, true

# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", locals: {
#  which_fake_page: "Rendering a fake page with a local variable" }

# General configuration

# Reload the browser automatically whenever files change
configure :development do
  activate :livereload
end

activate :blog do |blog|
  blog.sources = "tutorials/tutorial{number}"
  blog.permalink = "tutorials/tutorial{number}.html"
  blog.layout = "tutorial_layout"
end

###
# Helpers
###

# Methods defined in the helpers block are available in templates
helpers do
  def page_title
    if current_page.data.title
      suffix = " - #{ current_page.data.title current_page.data.title}"
    else
      suffix = ""
    end
    "Уроки по OpenGL с сайта OGLDev#{suffix}"
  end
end

# Build-specific configuration
configure :build do
  # Minify CSS on build
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript
end
