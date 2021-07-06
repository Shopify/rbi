# typed: true
# frozen_string_literal: true

module RBI
  class CLI < ::Thor
    extend T::Sig
    include CLIHelper

    DEFAULT_PATH = "sorbet/rbi"

    class_option :color, type: :boolean, default: true
    class_option :quiet, type: :boolean, default: false, aliases: :q
    class_option :verbose, type: :boolean, default: false, aliases: :v
    class_option :netrc, type: :boolean, default: true
    class_option :netrc_file, type: :string
    class_option :central_repo_slug, type: :string
    class_option :mock_index_file, type: :string

    desc "clean", "Remove all gem RBIs from local project"
    def clean
      context.clean
    end

    # TODO: Support triggering this command outside of root directory
    desc "init", "Initialize a project by retrieving all gem RBIs from central repository"
    def init
      context.init
    end

    desc "generate foo 1.0.0", "Generates RBI for a given gem. To use Sorbet in your project, use `rbi update` instead"
    option "source", type: :string, default: nil, desc: "Download gem from this source"
    option "git", type: :string, default: nil, desc: "Download gem from this git repo"
    option "branch", type: :string, default: nil, desc: "Install gem from this git branch"
    option "path", type: :string, default: nil, desc: "Install gem from this path"
    def generate(name, version = nil)
      source = options["source"]
      git = options["git"]
      path = options["path"]
      branch = options["branch"]

      context.generate(name, version: version, source: source, git: git, branch: branch, path: path)
    end

    desc "merge", "Merge two RBI files together"
    # TODO: options: clean, keep, resolve, annotate (left/right)
    option "output", type: :string, aliases: :o, default: nil, desc: "Save output to a file"
    def merge(rbi1, rbi2)
      rbi, conflicts = context.merge(rbi1, rbi2)

      output_path = options[:output]
      if output_path
        File.write(output_path, rbi)
      else
        puts rbi
      end

      logger = self.logger
      unless conflicts.empty?
        conflicts.each do |conflict|
          logger.error("Merge conflict between definitions `#{rbi1}##{conflict.left}` and `#{rbi2}##{conflict.right}`")
          # TODO: error sections & show source
        end
        exit(1)
      end
    end

    desc "update", "Update local gem RBIs"
    def update
      context.update
    end

    desc "push foo 1.0.0 sorbet/rbi/gems/foo@1.0.0.rbi", "Pushes rbi file to central repo and opens a pull request"
    def push(name, version, path)
      context.push(name, version, path)
    end

    desc "bump foo 1.0.0", "Generates RBI for a given gem reusing the RBI from the previous version"
    option "source", type: :string, default: nil, desc: "Download gem from this source"
    option "git", type: :string, default: nil, desc: "Download gem from this git repo"
    option "branch", type: :string, default: nil, desc: "Install gem from this git branch"
    option "path", type: :string, default: nil, desc: "Install gem from this path"
    # TODO: options: clean, keep, resolve, annotate (left/right)
    def bump(name, version)
      source = options["source"]
      git = options["git"]
      path = options["path"]
      branch = options["branch"]

      context.bump(name, version, source: source, git: git, branch: branch, path: path)
    end

    def self.exit_on_failure?
      true
    end
  end
end
