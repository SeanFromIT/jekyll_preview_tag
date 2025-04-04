#
#  Jekyll Preview Tag - Generate link previews inside you articles.
#  This plugin uses nokogiri and ruby-readability to create a preview and create a local cached snippet.
#  By: Aleks Maksimow, Kaffeezucht.de
#
#  Required Gems/Libraries: nokogiri, open-uri, ruby-readability, digest
#
#  Usage:
#
#  1. Generate a new folder called "_cache" in your Jekyll directory.
#     This will hold all linked snippets, so you don't need to regenerate them on every regeneration of your site.
#
#  2. Use the following link syntax:
#
#     {% preview http://example.com/some-article.html %}
#
#  3. In case we can't fetch the Title from a linksource, you can set it manually:
#
#     {% preview "Some Article" http://example.com/some-article.html %}
#
#  Feel free to send a pull-request: https://github.com/aleks/jekyll_preview_tag
#

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'readability'
require 'digest'

module Jekyll
  class PreviewTag < Liquid::Tag

    @tag_text, @link_url, @link_title = nil

    def initialize(tag_name, tag_text, tokens)
      super
      @tag_text = tag_text
    end

    def build_preview_content
      if cache_exists?(@link_url)
        @preview_content = read_cache(@link_url).to_s
      else
        #the .read fixes utf-8 encoding issues with nokogiri
        source = Nokogiri::HTML(URI.open(@link_url).read)

        #if you set the title, you probably want to override it
        @preview_title = @link_title
        @preview_text, @preview_img_url = nil
        head_tag = source.css('head')
        
        unless @preview_title.nil?
          #try getting title:
          if head_tag.css('meta[property="og:title"]').first
            @preview_title = cleanup(head_tag.css('meta[property="og:title"]').first["content"])
          elsif head_tag.css('meta[name="twitter:title"]').first
            @preview_title = cleanup(head_tag.css('meta[name="twitter:title"]').first["content"])
          elsif head_tag.css('title').first
            @preview_title = cleanup(head_tag.css('title').first["content"])
          elsif head_tag.css('meta[name="dcterms.title"]').first
            @preview_title = cleanup(head_tag.css('meta[name="dcterms.title"]').first["content"])
          elsif source.css('.entry-title').first
            @preview_title = cleanup(source.css('.entry-title').first.content)
          elsif source.css('.article_title').first
            @preview_title = cleanup(source.css('.article_title').first.content)
          elsif source.css('h1').first
            @preview_title = cleanup(source.css('h1').first.content)
          elsif source.css('h2').first
            @preview_title = cleanup(source.css('h2').first.content)
          elsif source.css('h3').first
            @preview_title = cleanup(source.css('h3').first.content)
          end
        end

        #try getting preview text:
        if head_tag.css('meta[property="og:description"]').first
          @preview_text = cleanup(head_tag.css('meta[property="og:description"]').first["content"])
        elsif head_tag.css('meta[name="twitter:description"]').first
          @preview_text = cleanup(head_tag.css('meta[name="twitter:description"]').first["content"])
        elsif head_tag.css('meta[name="dcterms.description"]').first
          @preview_text = cleanup(head_tag.css('meta[name="dcterms.description"]').first["content"])
        else
          @preview_text = get_content(source)
        end

        if head_tag.css('meta[property="og:image"]').first
          @preview_img_url = head_tag.css('meta[property="og:image"]').first["content"]
        elsif head_tag.css('meta[name="twitter:image"]').first
          @preview_img_url = head_tag.css('meta[name="twitter:image""]').first["content"]
        elsif head_tag.css('link[rel="image_src"]').first
          @preview_img_url = head_tag.css('link[rel="image_src"]').first["href"]
        end

        @preview_content = "<h4><a href='#{@link_url}' target='_blank'>#{@preview_title.to_s}</a></h4><img width='64' src='#{@preview_img_url}' /><small>#{@preview_text.to_s}</small>"

        write_cache(@link_url, @preview_content)
      end
    end

    def render(context)
      unless @tag_text.nil?
        rendered_text = Liquid::Template.parse(@tag_text).render(context)
        @link_url = rendered_text.scan(/https?:\/\/[\S]+/).first.to_s
        @link_title = rendered_text.scan(/\"(.*)\"/)[0].to_s.gsub(/\"|\[|\]/,'')

        build_preview_content
      end
      %|#{@preview_content}|
    end

    def get_content(source)
      cleanup(Readability::Document.new(source.to_s, :tags => %w[]).content)
    end

    def cleanup(content)
      content = content.to_s.gsub(/\t/,'')
      if content.size < 200
        content
      else
        content[0..200] + '...'
      end
    end

    def cache_key(link_url)
      Digest::MD5.hexdigest(link_url.to_s)
    end

    def cache_exists?(link_url)
      File.exist?("_cache/#{cache_key(link_url)}")
    end

    def write_cache(link_url, content)
      File.open("_cache/#{cache_key(link_url)}", 'w') { |f| f.write(content) }
    end

    def read_cache(link_url)
      File.read("_cache/#{cache_key(link_url)}")
    end
  end
end

Liquid::Template.register_tag('preview', Jekyll::PreviewTag)
