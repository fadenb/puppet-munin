# Class: munin
#
# This class installs and configures Munin
#
# Parameters:
#
# Actions:
#
# Requires:
#   - The munin::params class
#
# Sample Usage:
#
class munin(
  $munin_server,
  $extra_allows       = false,
  $munin_node_address = $ipaddress,
  $log_file           = $munin::params::log_file,
  $pid_file           = $munin::params::pid_file,
  $group              = $munin::params::group,
  $base_packages      = $munin::params::base_packages,
  $extra_packages     = $munin::params::extra_packages,
  $node_config        = $munin::params::node_config,
  $node_service       = $munin::params::node_service,
  $plugins_conf       = $munin::params::plugins_conf,
  $plugins_dest       = $munin::params::plugins_dest,
  $plugins_source     = $munin::params::plugins_source,
  $plugins_path       = $munin::params::plugins_path,
  $confdir            = $munin::params::confdir,
  $export             = true,
  $export_conf_dir    = "/etc/munin/munin-conf.d",
) inherits munin::params {

  package { $base_packages:
    ensure => present,
  }

  if $extra_packages {
    package { $extra_packages: ensure => installed; }
  }

  # Rebuild the database, but only when the file changes
  exec { "service $node_service restart":
    path        => ['/usr/sbin', '/usr/bin', '/sbin'],
    subscribe   => [
      File[$confdir],
      File[$plugins_dest],
    ],
    refreshonly => true,
  }

  # create $confdir and $confdir/plugins-conf.d/ before the package is installed
  # + create configs before package is installed to ensure service that may be
  # automatically started by the package manager is using puppetized config
  file { $confdir:
    ensure => directory,
  }
  file {"$confdir/plugin-conf.d":
    ensure => directory,
  }

  # Write the node configuration
  file { $node_config:
    content => template('munin/munin-node.conf.erb'),
    ensure  => present,
    notify  => Service[$node_service],
    require => File[$confdir],
    before  => [Package[$base_packages], Package[$extra_packages]],
  }

  # Create the plugin configuration
  file { $plugins_conf:
    content => template('munin/munin-plugins.conf.erb'),
    ensure  => present,
    notify  => Service[$node_service],
    require => File["$confdir/plugin-conf.d"],
    before  => [Package[$base_packages], Package[$extra_packages]],
  }

  file { "${plugins_conf}.sample": ensure => absent }

  # Purge plugins we are not managing
  file { $plugins_dest:
    ensure  => directory,
    owner   => 'root',
    group   => $group,
    mode    => '0755',
    recurse => true,
    purge   => true,
    notify  => Service[$node_service],
    require => [Package[$base_packages], Package[$extra_packages]],
  }

  # Get the directory names
  $logdir = inline_template( "<%= File.dirname( log_file ) %>" )
  $piddir = inline_template( "<%= File.dirname( pid_file ) %>" )

  # Create the directories
  file { $logdir:
    ensure  => directory,
    owner   => 'munin',
    mode    => '0750',
    require => Package[$base_packages]
  }

  file { $piddir:
    ensure  => directory,
    owner   => 'munin',
    group   => $group,
    mode    => '0770',
    require => Package[$base_packages];
  }

  # This is kinda dirty, but it does make a bunch of crappy plugins
  # "just work" without having to fix things in munin. See the vile
  # use of "$MUNIN_PLUGSTSTE" and the likes. (Some are even more
  # obscured in the CPAN libraries.
  if $kernel == "FreeBSD" {
    file { '/var/munin/plugin-state':
      ensure  => symlink,
      target  => $piddir,
      force   => true,
      require => File[$piddir]
    }
  }

  service { $node_service:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    subscribe  => [
      File[$node_config],
      File[$plugins_conf],
      File[$plugins_dest],
    ],
    require    => [
      File[$node_config],
      Package[$base_packages],
      Package[$extra_packages],
      File[$logdir],
      File[$piddir],
      File[$plugins_dest],
    ],
  }

  # Export the node resource to the master
  if $export {
    @@file { "${export_conf_dir}/${fqdn}":
      content => template('munin/munin-host.conf.erb'),
      ensure  => present,
      tag     => 'munin_host',
    }
  }
}
