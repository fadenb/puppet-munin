# Class: munin::plugin
#
# This definitions installs and configures Munin plug-ins, but is at
# least slightly versitile.
#
# Parameters:
#  fromname =>
#     so you can use name as "ifstat_eth0" and fromanme to ifstat_
#  plugindest/path => different paths.
#
# Requires:
#   - The munin class
#
define munin::plugin (
  $fromname   = undef,
  $ensure     = present,
  $pluginpath = $munin::params::plugins_source,
  $plugindest = $munin::params::plugins_dest,
) {

  if ! defined('::munin') {
    fail('You must declare the munin class before using this defined resource type')
  }

  if $fromname == undef {
    $sourcename = $name
  } else {
    $sourcename = $fromname
  }

  $realensure = $ensure ? {
    present   => link,
    link      => link,
    'present' => link,
    'link'    => link,
    absent    => absent,
    'absent'  => absent,
  }

  file { "${plugindest}/${name}":
    ensure => $realensure,
    target => "${pluginpath}/${sourcename}",
    notify => Service[$munin::params::node_service],
  }
}
