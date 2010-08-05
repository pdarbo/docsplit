# The Docsplit module delegates to the Java PDF extractors.
module Docsplit

  VERSION       = '0.2.1' # Keep in sync with gemspec.

  ROOT          = File.expand_path(File.dirname(__FILE__) + '/..')

  CLASSPATH     = "#{ROOT}/build#{File::PATH_SEPARATOR}#{ROOT}/vendor/'*'"

  LOGGING       = "-Djava.util.logging.config.file=#{ROOT}/vendor/logging.properties"

  HEADLESS      = "-Djava.awt.headless=true"

  METADATA_KEYS = [:author, :date, :creator, :keywords, :producer, :subject, :title, :length]

  DEPENDENCIES  = {:java => false, :gm => false, :pdftotext => false, :pdftk => false, :tesseract => false}

  # Check for all dependencies, and warn of their absence.
  dirs = ENV['PATH'].split(File::PATH_SEPARATOR)
  DEPENDENCIES.each_key do |dep|
    dirs.each do |dir|
      if File.executable?(File.join(dir, dep.to_s))
        DEPENDENCIES[dep] = true
        break
      end
    end
    warn "Warning: Docsplit dependency #{dep} not found." if !DEPENDENCIES[dep]
  end

  # Raise an ExtractionFailed exception when the PDF is encrypted, or otherwise
  # broke.
  class ExtractionFailed < StandardError; end

  # Use the ExtractPages Java class to burst a PDF into single pages.
  def self.extract_pages(pdfs, opts={})
    pdfs = ensure_pdfs(pdfs)
    PageExtractor.new.extract(pdfs, opts)
  end

  # Use the ExtractText Java class to write out all embedded text.
  def self.extract_text(pdfs, opts={})
    pdfs = ensure_pdfs(pdfs)
    TextExtractor.new.extract(pdfs, opts)
  end

  # Use the ExtractImages Java class to rasterize a PDF into each page's image.
  def self.extract_images(pdfs, opts={})
    pdfs = ensure_pdfs(pdfs)
    opts[:pages] = normalize_value(opts[:pages]) if opts[:pages]
    ImageExtractor.new.extract(pdfs, opts)
  end

  # Use JODCConverter to extract the documents as PDFs.
  def self.extract_pdf(docs, opts={})
    [docs].flatten.each do |doc|
      basename = File.basename(doc, File.extname(doc))
      run "-jar #{ROOT}/vendor/jodconverter/jodconverter-cli-2.2.2.jar #{doc} #{opts[:output] || '.'}/#{basename}.pdf", [], {}
    end
  end

  # Define custom methods for each of the metadata keys that we support.
  # Use the ExtractInfo Java class to print out a single bit of metadata.
  METADATA_KEYS.each do |key|
    instance_eval <<-EOS
      def self.extract_#{key}(pdfs, opts={})
        pdfs = ensure_pdfs(pdfs)
        InfoExtractor.new.extract(:#{key}, pdfs, opts)
      end
    EOS
  end


  private

  # Runs a Java command, with quieted logging, and the classpath set properly.
  def self.run(command, pdfs, opts, return_output=false)
    pdfs    = [pdfs].flatten.map{|pdf| "\"#{pdf}\""}.join(' ')
    args    = parse_options(opts)
    cmd     = "java #{HEADLESS} #{LOGGING} -cp #{CLASSPATH} #{command} #{args} #{pdfs} 2>&1"
    result  = `#{cmd}`.chomp
    raise ExtractionFailed, result if $? != 0
    return return_output ? (result.empty? ? nil : result) : true
  end

end

require 'tmpdir'
require 'fileutils'
require "#{Docsplit::ROOT}/lib/docsplit/image_extractor"
require "#{Docsplit::ROOT}/lib/docsplit/argument_parser"
require "#{Docsplit::ROOT}/lib/docsplit/transparent_pdfs"
require "#{Docsplit::ROOT}/lib/docsplit/text_extractor"
require "#{Docsplit::ROOT}/lib/docsplit/page_extractor"
require "#{Docsplit::ROOT}/lib/docsplit/info_extractor"
