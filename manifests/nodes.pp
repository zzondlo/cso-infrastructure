

node 'puppet' inherits basenode {
	include puppet::master
	include ircbot
}


node 'demo4-cp.sjc.vmops.com' inherits basenode {

}
