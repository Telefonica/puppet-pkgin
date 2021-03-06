require "puppet/provider/package"

Puppet::Type.type(:package).provide :pkgin, :parent => Puppet::Provider::Package do
  desc "Package management using pkgin, a binary package manager for pkgsrc."

  commands :pkgin => "pkgin"

  defaultfor :operatingsystem => :dragonfly
  defaultfor :solarisflavour => :smartos

  has_feature :installable, :uninstallable, :upgradeable, :versionable

  def self.parse_pkgin_line(package)

    # e.g.
    #   vim-7.2.446 =        Vim editor (vi clone) without GUI
    match, name, version, status = *package.match(/(\S+)-(\S+)(?: (=|>|<))?\s+.+$/)
    if match
      {
        :name     => name,
        :ensure   => version,
        :status   => status
      }
    end
  end

  # packages : list of packages for the current provider declared on manifest
  def self.prefetch(packages)
    # it is unclear if we should call the parent method here. The work done
    #    there seems redundant, at least if pkgin is default provider.
    super
    pkgin("-y", :update)
  end

  # called in every run to collect packages present in the system
  # under 'apply', it is actually called from within the parent prefetch
  def self.instances
    pkgin(:list).split("\n").map do |package|
      new(parse_pkgin_line(package))
    end
  end

  # called for every resource in manifest not present in instances
  # it is not defined wether this should query local or remote packages
  # returned hash is stored on @property_hash, or '{:ensure=>:absent}' if nil
  # or false is returnedm, but in any case install/update is executed depending
  # on the value of the initial ensure attribute
  def query
    packages = parse_pkgsearch_line

    if not packages or packages.empty?
      if @resource[:ensure] == :absent
        notice "declared as absent but unavailable #{@resource.file}:#{resource.line}"
        return false
      else
        @resource.fail "No candidate to be installed"
      end
    end

    packages.first
  end

  def parse_pkgsearch_line
    packages = pkgin(:search, resource[:name]).split("\n")

    return nil if packages.length == 1

    # Remove the last three lines of help text.
    packages.slice!(-4, 4)

    pkglist = packages.map{ |line| self.class.parse_pkgin_line(line) }
    pkglist.select{ |package| resource[:name] == package[:name] }
  end

  def install
    if String === @resource[:ensure]
      pkgin("-y", :install, "#{resource[:name]}-#{resource[:ensure]}")
    else
      pkgin("-y", :install, resource[:name])
    end
  end

  def uninstall
    pkgin("-y", :remove, resource[:name])
  end

  def latest
    package = parse_pkgsearch_line.detect{ |package| package[:status] == '<' }
    return properties[:ensure] if not package
    notice  "Upgrading #{package[:name]} to #{package[:version]}"
    return package[:ensure]
  end

  def update
    pkgin("-y", :install, resource[:name])
  end

end
