require 'fileutils'

class ZipFileWrapper
  attr_accessor :pages, :file
  @@tmp_path = File.dirname(__FILE__) + "/tmp"
  @@public_path = File.dirname(__FILE__) + "/public"

  def directory
    @directory ||= "#{@@tmp_path}/#{directory_name}"
  end
  def zip_filename
    @zip_filename ||= File.basename(zip_filepath)
  end
  def zip_filepath
    @zip_filepath ||= "#{directory}.zip"
  end
  def directory_name
    "export-#{Process.pid}"
  end

  def initialize(pages = [])
    @pages = pages
    if block_given?
      create_file!
      yield(self)
    end
  end

  def each(&block)
    @file.each(&block)
  end

  def create_file!
    # Zip::ZipFile.open("#{@@tmp_path}/export-#{Process.pid}", Zip::ZipFile::CREATE) do |zipfile|
    #   @pages.each do |page|
    #     slug = page.slug ~= /\\/$/ ? "#{page.slug}index" : page.slug
    #     filename = "#{slug}.html"
    #     zipfile.dir.mkdir(File.dirname(filename))
    #     zipfile.file.open(filename, "w") { |f| f.puts page.rendered_body }
    #   end
    # end

    FileUtils.rmdir(directory)

    @pages.each do |page|
      slug = page.slug =~ /\/$/ ? "#{page.slug}index" : page.slug
      nested_depth = slug.scan(/\//).size
      dots = (1...nested_depth).map { |n| ".." }.join("/") + "/" # so it can be ../../master.css and all of that
      dots = "" if dots == "/"

      name = "#{directory}/#{slug}.html"

      FileUtils.mkdir_p(File.dirname(name))

      File.open(name, "w") do |f|
        html = %Q{<!doctype html>
                  <html>
                    <head>
                      <link rel="stylesheet" href="#{dots}master.css" type="text/css">
                      <title>#{page.title}</title>
                    </head>
                    <body>
                      <div id="content">#{page.rendered_body}</div>
                    </body>
                  </html>
        }

        # change any url that begins with / to be relative instead and append
        # .html unless they have an extension already
        html.gsub!(/="\/([^"\.]+)"/, "=\"#{dots}\\1.html\"")

        f.puts html
      end
    end

    File.open("#{directory}/master.css", "w") { |f| f.puts File.read("#{@@public_path}/master.css") }

    puts `cd #{@@tmp_path} && zip -r #{directory_name} #{directory_name}`

    @file = File.open(zip_filepath, "r")
    self
  end
end
