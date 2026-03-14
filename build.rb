#!/usr/bin/env ruby
require "yaml"
require "json"
require "digest"
require "fileutils"

SKILLS_DIR = File.expand_path("registry", __dir__)
DIST_DIR   = File.expand_path("dist", __dir__)
BASE_URL   = "https://skills.erinos.ai"

FileUtils.rm_rf(DIST_DIR)
FileUtils.mkdir_p(DIST_DIR)

providers = {}

Dir[File.join(SKILLS_DIR, "*/provider.yml")].sort.each do |provider_path|
  provider_dir  = File.dirname(provider_path)
  provider_name = File.basename(provider_dir)

  # Collect skill names and descriptions from SKILL.md frontmatter
  skills = Dir[File.join(provider_dir, "*/SKILL.md")].sort.filter_map do |path|
    content = File.read(path)
    match = content.match(/\A---\n(.*?)^---\n/m)
    next unless match

    fm = YAML.safe_load(match[1])
    { "name" => fm["name"], "description" => fm["description"] }
  end

  # Build tarball
  tarball = "#{provider_name}.tar.gz"
  tarball_path = File.join(DIST_DIR, tarball)
  system("tar", "-czf", tarball_path, "-C", SKILLS_DIR, provider_name, exception: true)

  sha256 = Digest::SHA256.hexdigest(File.binread(tarball_path))

  # Build description from skill descriptions
  description = skills.reject { |s| s["name"].end_with?("-shared") }
                      .map { |s| s["description"] }
                      .join(" ")

  providers[provider_name] = {
    "description" => description,
    "skills" => skills.map { |s| s["name"] },
    "sha256" => sha256,
    "url" => "#{BASE_URL}/#{tarball}"
  }
end

index = {
  "version" => 1,
  "updated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "providers" => providers
}

File.write(File.join(DIST_DIR, "index.json"), JSON.pretty_generate(index))

puts "Built #{providers.size} providers:"
providers.each { |name, info| puts "  #{name}: #{info["skills"].size} skills" }
