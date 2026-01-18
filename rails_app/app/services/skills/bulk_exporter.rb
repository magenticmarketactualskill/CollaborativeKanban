require "zip"

module Skills
  class BulkExporter
    def initialize(skills)
      @skills = skills
    end

    def to_zip
      stringio = Zip::OutputStream.write_buffer do |zio|
        @skills.each do |skill|
          exporter = Exporter.new(skill)
          zio.put_next_entry(exporter.filename)
          zio.write(exporter.to_markdown)
        end

        # Add a manifest file
        zio.put_next_entry("manifest.json")
        zio.write(manifest.to_json)
      end

      stringio.rewind
      stringio.read
    end

    def to_file(path)
      File.binwrite(path, to_zip)
      path
    end

    private

    def manifest
      {
        exported_at: Time.current.iso8601,
        count: @skills.size,
        skills: @skills.map do |skill|
          {
            slug: skill.slug,
            name: skill.name,
            version: skill.version,
            category: skill.category,
            file: "#{skill.slug}.md"
          }
        end
      }
    end
  end
end
