# Class: jira
#
# Parameters:
#  ${jira_installdir} installation target, default /usr/local
#  ${jira_dir}        softlink which points to jira files, default /usr/local/jira
#  ${jira_datadir}    jira database directory, default /usr/local/jira-data
#  ${jira_version}    jira software version, default match package name
#  ${jira_database}   mysql database name
#  ${jira_user}       mysql username
#  ${jira_password}   mysql password
#  optional: (not implemented)
#  ${jira_serverport} default 8000
#  ${jira_connectorport} default 8080
#
# Actions:
#  This will install jira to /usr/local/jira/ -> ../jira-{version}/
#  Packages: jdk1.6, libXp, mysql,
#  The initial mysql database will be populated with sensible defaults and mysql database.
#
# Requires:
#  module mysql
#
# Sample Usage:
#

class jira {
  include mysql::server
  include jira::params
  include httpd::proxy

  # jira installation defaults
  if $params::jira_installdir=='' {
    notice ("params::jira_installdir unset, assuming /usr/local")
    $jira_installdir='/usr/local'
  } else {
    $jira_installdir=$params::jira_installdir
  }
  if $params::jira_dir=='' {
    notice ("params::jira_dir unset, assuming /usr/local")
    $jira_dir='/usr/local/jira'
  } else {
    $jira_dir=$params::jira_dir
  }
  if $params::jira_datadir=='' {
    notice ("params::jira_datadir unset, assuming /usr/local")
    $jira_datadir='/usr/local/jira-data'
  } else {
    $jira_datadir=$params::jira_datadir
  }
  if $params::jira_version=='' {
    notice ("params::jira_version unset, assuming /usr/local")
    $jira_version='atlassian-jira-4.1.3'
  } else {
    $jira_version=$params::jira_version
  }

  # mysql configuration
  if $params::jira_database=='' {
    notice ("params::jira_database, assuming jira")
    $jira_database='jira'
  } else {
    $jira_database=$params::jira_database
  }
  if $params::jira_user=='' {
    notice ("params::jira_user, assuming jira")
    $jira_user='jira'
  } else {
    $jira_user=$params::jira_user
  }
  if $params::jira_password=='' {
    notice ("params::jira_password, assuming jira")
    $jira_password='puppetrocks'
  } else {
    $jira_password=$params::jira_password
  }



  package {
    $params::default_packages:
      ensure => present,
  }

  File { owner => '0', group => 'root', mode => '0644' }
  Exec { path => "/bin:/sbin:/usr/bin:/usr/sbin" }


  file { "${jira_installdir}":
    ensure => directory,
  }

  exec { "extract_jira":
    command => "gtar -xf /tmp/atlassian-jira-4.4.4.tar.gz -C ${jira_installdir}",
    require => File [ "${jira_installdir}" ],
    subscribe => Exec [ "dl_cf" ],
    creates => "${jira_installdir}/${jira_version}",
  }


  exec {"dl_cf":
    command => "wget http://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-4.4.4.tar.gz",
    cwd => "/tmp",
    creates => "/tmp/atlassian-jira-4.4.4.tar.gz",
  }

  file { "${jira_dir}":
    ensure => "${jira_installdir}/${jira_version}",
    require => Exec [ "extract_jira" ];
  }


  file { "jira-init.properties":
    name => "${jira_installdir}/${jira_version}/jira/WEB-INF/classes/jira-init.properties",
    content => template ("jira/jira-init.properties.erb"),
    subscribe => Exec [ "extract_jira" ],
  }


  file { "/etc/init.d/jira":
    mode => '0755',
    content => template ("jira/jira.erb"),
  }

  service { "jira":
    ensure      => running,
    enable      => true,
    hasstatus   => true,
    require     => [ File[ "/etc/init.d/jira" ,
                   "jira-init.properties" 
                   ],
                     Exec[ "create_${jira_database}" ]
                   ],
  }


  service { "iptables": 
    ensure => stopped,
    hasstatus => true,
  } 

  file {"/tmp/jira.sql":
    source => "puppet:///modules/jira/jira.sql",
  }



  # mysql database creation and table setup (onetime)
  exec { "create_${jira_database}":
    command => "mysql -e \"create database ${jira_database}; \
               grant all on ${jira_database}.* to '${jira_user}'@'localhost' \
               identified by '${jira_password}';\"; \ ", 
        

######       mysql ${jira_database} < /tmp/jira.sql",
   unless => "/usr/bin/mysql ${jira_database}",
   require => [ Service[ "mysqld" ],
                 File[ "/tmp/jira.sql" ] ],
  }

  file {"/etc/httpd/conf.d/jira.conf":
    source => "puppet:///jira/jira.conf",
  }
}