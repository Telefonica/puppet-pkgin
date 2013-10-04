Facter.add(:solarisflavour) do
  confine :operatingsystem => :Solaris
  setcode do
    # Use uname -v because /etc/release can change in zones under SmartOS.
    # It's apparently not trustworthy enough to rely on for this fact.
    output = Facter::Util::Resolution.exec('uname -v')
    if output =~ /^joyent_/
      "SmartOS"
    elsif output =~ /^oi_/
      "OpenIndiana"
    elsif output =~ /^omnios-/
      "OmniOS"
    elsif FileTest.exists?("/etc/debian_version")
      "Nexenta"
    else
      "Solaris"
    end
  end
end
