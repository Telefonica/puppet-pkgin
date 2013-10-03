require "puppet/provider/package"

Puppet::Type.type(:package).provide :pkgin, :parent => Puppet::Provider::Package do
  desc "Package management using pkgin, a binary package manager for pkgsrc."

  commands :pkgin => "pkgin"

  has_feature :installable, :uninstallable, :upgradeable

  def self.parse(package, force_status=nil)

    # e.g.
    #   vim-7.2.446 =        Vim editor (vi clone) without GUI
    match, name, version, status = *package.match(/(\S+)-(\S+)(?: (=|>|<))?\s+.+$/)
    if match
      ensure_status = if force_status
        force_status
      elsif status
        :present
      else
        :absent
      end

      {
        :name     => name,
        :version  => version,
        :ensure   => ensure_status,
        :provider => :pkgin
      }
    else
      err "Something didn't match the expected regexp at #{package}"
    end
  end

  def self.instances
    pkgin(:list).split("\n").map do |package|
      new(parse(package, :present))
    end
  end

  def query
    packages = pkgin(:search, resource[:name]).split("\n")

    # Remove the last three lines of help text.
    packages.slice!(-3, 3)

    matching_package = []
    packages.select{ |pkg| pkg.start_with?("#{resource[:name]}") }.each do |package|
      properties = self.class.parse(package)
      matching_package = properties if properties && resource[:name] == properties[:name]
    end

    if matching_package.length > 1
      warning( "Multiple instances matching #{resource[:name]} : #{matching_package}" )
    end

    matching_package.first
  end

  def install
    pkgin("-y", :install, resource[:name])
  end

  def uninstall
    pkgin("-y", :remove, resource[:name])
  end

  def latest
    # -f seems required when repositories.conf changes
    pkgin("-yf", :update)
    package = self.query
    if package[:status] == '<'
      notice  "Upgrading #{package[:name]} to #{package[:version]}"
      pkgin("-y", :install, package[:name])
    else
      true
    end
  end

end

