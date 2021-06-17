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

    desc "clean", "Remove all gem RBIs from local project"
    def clean
      context.clean
    end

    # TODO: Support triggering this command outside of root directory
    desc "init", "Initialize a project by retrieving all gem RBIs from central repository"
    option "mock-github-client", type: :boolean, default: false
    def init
      client = self.client(options["mock-github-client"])
      client.init(context)
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
      generate_rbi(name, version: version, source: source, git: git, branch: branch, path: path)
    end

    desc "update", "Update local gem RBIs"
    option "mock-github-client", type: :boolean, default: false
    def update
      client = self.client(options["mock-github-client"])
      client.update(context)
    end

    def self.exit_on_failure?
      true
    end
  end
end
