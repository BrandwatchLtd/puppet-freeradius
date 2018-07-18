# Base class to install FreeRADIUS
class freeradius (
  $control_socket    = false,
  $max_servers       = '4096',
  $max_requests      = '4096',
  $mysql_support     = false,
  $pgsql_support     = false,
  $perl_support      = false,
  $utils_support     = false,
  $ldap_support      = false,
  $krb5_support      = false,
  $wpa_supplicant    = false,
  $winbind_support   = false,
  $log_destination   = 'files',
  $syslog            = false,
  $log_auth          = 'no',
  $preserve_mods     = true,
  $correct_escapes   = true,
  $manage_logpath    = true,
  $package_ensure    = 'installed',
  $radacctdir        = $freeradius::params::radacctdir,
  $fr_user           = $freeradius::params::fr_user,
  $fr_group          = $freeradius::params::fr_group,
  $fr_package        = $freeradius::params::fr_package,
  $fr_service        = $freeradius::params::fr_service,
  $fr_basepath       = $freeradius::params::fr_basepath,
  $fr_version        = $freeradius::params::fr_version,
  $fr_modulepath     = $freeradius::params::fr_modulepath,
  $fr_logpath        = $freeradius::params::fr_logpath,
  $fr_pidfile        = $freeradius::params::fr_pidfile,
  $fr_daemon_user    = $freeradius::params::fr_user,
  $fr_daemon_group   = $freeradius::params::fr_group,
  $fr_wbpriv_user    = $freeradius::params::fr_wbpriv_user,
  $fr_wpa_supplicant = $freeradius::params::fr_wpa_supplicant,
) inherits freeradius::params {

  if $fr_version !~ /^3/ {
    notify { 'This module is only compatible with FreeRADIUS 3.': }
  }

  validate_re($log_destination, '^(files|syslog|stdout|stderr)$',
    "log_destination value (${log_destination}) is not a valid value")

  validate_re($package_ensure, '^(installed|latest)$', 'package_ensure must be one of installed, latest')

  if $control_socket == true {
    warning('Use of the control_socket parameter in the freeradius class is deprecated. Please use the freeradius::control_socket class instead.')
  }

  # Always restart the service after every module operation
  Freeradius::Module {
    notify => Service[$fr_service]
  }

  file { 'radiusd.conf':
    name    => "${fr_basepath}/radiusd.conf",
    mode    => '0644',
    owner   => 'root',
    group   => $fr_group,
    content => template('freeradius/radiusd.conf.erb'),
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }

  # Create various directories
  file { [
    $fr_basepath,
    "${fr_basepath}/statusclients.d",
    "${fr_basepath}/conf.d",
    "${fr_basepath}/attr.d",
    "${fr_basepath}/users.d",
    "${fr_basepath}/policy.d",
    "${fr_basepath}/dictionary.d",
    "${fr_basepath}/sites-available",
    "${fr_basepath}/mods-available",
    "${fr_basepath}/scripts",
  ]:
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => $fr_group,
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }

  # Create these directories separately so we can set purge option
  # Anything in these dirs NOT managed by puppet will be removed!
  file { [
    "${fr_basepath}/certs",
    "${fr_basepath}/clients.d",
    "${fr_basepath}/listen.d",
    "${fr_basepath}/sites-enabled",
    "${fr_basepath}/mods-enabled",
    "${fr_basepath}/instantiate",
  ]:
    ensure  => directory,
    purge   => true,
    recurse => true,
    mode    => '0755',
    owner   => 'root',
    group   => $fr_group,
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }

  # Preserve some stock modules
  if ($preserve_mods) {
    freeradius::module { [
      'always',
      'cache_eap',
      'chap',
      'detail',
      'detail.log',
      'digest',
      'dynamic_clients',
      'echo',
      'exec',
      'expiration',
      'expr',
      'files',
      'linelog',
      'logintime',
      'mschap',
      'ntlm_auth',
      'pap',
      'passwd',
      'preprocess',
      'radutmp',
      'realm',
      'replicate',
      'soh',
      'sradutmp',
      'unix',
      'unpack',
      'utf8',
    ]:
      preserve => true,
    }
  }

  # Set up concat policy file, as there is only one global policy
  # We also add standard header and footer
  concat { "${fr_basepath}/policy.conf":
    owner   => 'root',
    group   => $fr_group,
    mode    => '0640',
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }
  concat::fragment { 'policy_header':
    target  => "${fr_basepath}/policy.conf",
    content => "policy {\n",
    order   => 10,
  }
  concat::fragment { 'policy_footer':
    target  => "${fr_basepath}/policy.conf",
    content => "}\n",
    order   => '99',
  }

  # Set up concat template file
  concat { "${fr_basepath}/templates.conf":
    owner   => 'root',
    group   => $fr_group,
    mode    => '0640',
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }
  concat::fragment { 'template_header':
    target => "${fr_basepath}/templates.conf",
    source => 'puppet:///modules/freeradius/template.header',
    order  => '05',
  }
  concat::fragment { 'template_footer':
    target  => "${fr_basepath}/templates.conf",
    content => "}\n",
    order   => '95',
  }


  # Set up concat proxy file
  concat { "${fr_basepath}/proxy.conf":
    owner   => 'root',
    group   => $fr_group,
    mode    => '0640',
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }
  concat::fragment { 'proxy_header':
    target  => "${fr_basepath}/proxy.conf",
    content => "# Proxy config\n\n",
    order   => '05',
  }

  # Set up attribute filter file
  concat { "${fr_basepath}/mods-available/attr_filter":
    owner   => 'root',
    group   => $fr_group,
    mode    => '0640',
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }
  file { "${fr_modulepath}/attr_filter":
    ensure => link,
    target => '../mods-available/attr_filter',
  }

  # Install default attribute filters
  concat::fragment { 'attr-default':
    target  => "${fr_basepath}/mods-available/attr_filter",
    content => template('freeradius/attr_default.erb'),
    order   => 10,
  }

  # Install a slightly tweaked stock dictionary that includes
  # our custom dictionaries
  concat { "${fr_basepath}/dictionary":
    owner   => 'root',
    group   => $fr_group,
    mode    => '0640',
    require => [Package[$fr_package], Group[$fr_group]],
  }
  concat::fragment { 'dictionary_header':
    target => "${fr_basepath}/dictionary",
    source => 'puppet:///modules/freeradius/dictionary.header',
    order  => 10,
  }
  concat::fragment { 'dictionary_footer':
    target => "${fr_basepath}/dictionary",
    source => 'puppet:///modules/freeradius/dictionary.footer',
    order  => 90,
  }

  # Install a huntgroups file
  concat { "${fr_basepath}/mods-config/preprocess/huntgroups":
    owner   => 'root',
    group   => $fr_group,
    mode    => '0640',
    require => [Package[$fr_package], Group[$fr_group]],
  }
  concat::fragment { 'huntgroups_header':
    target => "${fr_basepath}/mods-config/preprocess/huntgroups",
    source => 'puppet:///modules/freeradius/huntgroups.header',
    order  => 10,
  }


  # Install FreeRADIUS packages
  package { 'freeradius':
    ensure => $package_ensure,
    name   => $fr_package,
  }
  if $mysql_support {
    package { 'freeradius-mysql':
      ensure => $package_ensure,
    }
  }
  if $pgsql_support {
    package { 'freeradius-postgresql':
      ensure => $package_ensure,
    }
  }
  if $perl_support {
    package { 'freeradius-perl':
      ensure => $package_ensure,
    }
  }
  if $utils_support {
    package { 'freeradius-utils':
      ensure => $package_ensure,
    }
  }
  if $ldap_support {
    package { 'freeradius-ldap':
      ensure => $package_ensure,
    }
  }
  if $krb5_support {
    package { 'freeradius-krb5':
      ensure => $package_ensure,
    }
  }
  if $wpa_supplicant {
    package { 'wpa_supplicant':
      ensure => $package_ensure,
      name   => $fr_wpa_supplicant,
    }
  }

  # radiusd always tests its config before restarting the service, to avoid outage. If the config is not valid, the service
  # won't get restarted, and the puppet run will fail.
  service { $fr_service:
    ensure     => running,
    name       => $fr_service,
    require    => [Exec['radiusd-config-test'], File['radiusd.conf'], User[$fr_user], Package[$fr_package],],
    enable     => true,
    hasstatus  => $fr_service_has_status,
    hasrestart => true,
  }

  # We don't want to create the radiusd user, just add it to the
  # wbpriv group if the user needs winbind support. We depend on
  # the FreeRADIUS package to be sure that the user has been created
  user { $fr_user:
    ensure  => present,
    groups  => $winbind_support ? {
      true    => $fr_wbpriv_user,
      default => undef,
    },
    require => Package[$fr_package],
  }

  # We don't want to add the radiusd group but it must be defined
  # here so we can depend on it. WE depend on the FreeRADIUS
  # package to be sure that the group has been created.
  group { $fr_group:
    ensure  => present,
    require => Package[$fr_package],
  }

  # Syslog rules
  if $syslog == true {
    rsyslog::snippet { '12-radiusd-log':
      content => "if \$programname == \'radiusd\' then ${fr_logpath}/radius.log\n&~",
    }
  }

  if $manage_logpath {
    # Make the radius log dir traversable
    file { [
      $fr_logpath,
      "${fr_logpath}/radacct",
    ]:
      mode    => '0750',
      require => Package[$fr_package],
    }

    file { "${fr_logpath}/radius.log":
      owner   => $fr_user,
      group   => $fr_group,
      seltype => 'radiusd_log_t',
      require => [Package[$fr_package], User[$fr_user], Group[$fr_group]],
    }
  }

  logrotate::rule { 'radacct':
    path          => "${fr_logpath}/radacct/*/*.log",
    rotate_every  => 'day',
    rotate        => 7,
    create        => false,
    missingok     => true,
    compress      => true,
    postrotate    => "kill -HUP `cat ${fr_pidfile}`",
    sharedscripts => true,
  }

  logrotate::rule { 'checkrad':
    path          => "${fr_logpath}/checkrad.log",
    rotate_every  => 'week',
    rotate        => 1,
    create        => true,
    missingok     => true,
    compress      => true,
    postrotate    => "kill -HUP `cat ${fr_pidfile}`",
    sharedscripts => true,
  }

  logrotate::rule { 'radiusd':
    path          => "${fr_logpath}/radius*.log",
    rotate_every  => 'week',
    rotate        => 26,
    create        => true,
    missingok     => true,
    compress      => true,
    postrotate    => "kill -HUP `cat ${fr_pidfile}`",
    sharedscripts => true,
  }

  # Placeholder resource for dh and random as they are dynamically generated, so they
  # exist in the catalogue and don't get purged
  file { ["${fr_basepath}/certs/dh", "${fr_basepath}/certs/random"]:
    require => Exec['dh', 'random'],
  }

  # Generate global SSL parameters
  exec { 'dh':
    command => "openssl dhparam -out ${fr_basepath}/certs/dh 1024",
    creates => "${fr_basepath}/certs/dh",
    require => File[$fr_basepath],
    path    => '/usr/bin',
  }

  # Generate global SSL parameters
  exec { 'random':
    command => "dd if=/dev/urandom of=${fr_basepath}/certs/random count=10 >/dev/null 2>&1",
    creates => "${fr_basepath}/certs/random",
    require => File[$fr_basepath],
    path    => '/bin',
  }

  # This exec tests the radius config and fails if it's bad
  # It isn't run every time puppet runs, but only when freeradius is to be restarted
  exec { 'radiusd-config-test':
    command     => 'sudo radiusd -XC | grep \'Configuration appears to be OK.\' | wc -l',
    returns     => 0,
    refreshonly => true,
    logoutput   => on_failure,
    path        => ['/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/'],
  }

  # Blank a couple of default files that will break our config. This is more effective than deleting them
  # as they won't get overwritten when FR is upgraded from RPM, whereas missing files are replaced.
  file { [
    "${fr_basepath}/clients.conf",
    "${fr_basepath}/sql.conf",
  ]:
    content => "# FILE INTENTIONALLY BLANK\n",
    mode    => '0644',
    owner   => 'root',
    group   => $fr_group,
    require => [Package[$fr_package], Group[$fr_group]],
    notify  => Service[$fr_service],
  }

  # Delete *.rpmnew and *.rpmsave files from the radius config dir because
  # radiusd stupidly reads these files in, and they break the config
  # This should be fixed in FreeRADIUS 2.2.0
  # http://lists.freeradius.org/pipermail/freeradius-users/2012-October/063232.html
  # Only affects RPM-based systems
  if $::osfamily == 'RedHat' {
    exec { 'delete-radius-rpmnew':
      command => "find ${fr_basepath} -name *.rpmnew -delete",
      onlyif  => "find ${fr_basepath} -name *.rpmnew | grep rpmnew",
      path    => ['/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/'],
    }
    exec { 'delete-radius-rpmsave':
      command => "find ${fr_basepath} -name *.rpmsave -delete",
      onlyif  => "find ${fr_basepath} -name *.rpmsave | grep rpmsave",
      path    => ['/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/'],
    }
  }
}
