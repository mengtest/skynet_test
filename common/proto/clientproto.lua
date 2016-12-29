.package {
	type 0 : integer
	session 1 : integer
	ud 2 : string
}

.character_overview{
	uuid 0 : integer
	level 1 : integer
	job 2 : integer
	rolename 3 : string
	createtime 4 : string
}

ping 1 {
	request {
		userid 0 : string
	}
	response {
		ok 0 : boolean
	}
}

#握手
handshake 2 {
	request {
		clientkey 0 : string
	}
	response {
		challenge 0 : string
		serverkey 1 : string
	}
}

challenge 3 {
	request {
		hmac 0 : string
	}
	response {
		result 0 : string
	}
}

#账号认证
auth 4 {
	request {
		etokens 0 : string
	}
}

#登录game
login 5 {
	request {
		handshake 0 : string
	}
	response {
		result 0 : string
	}
}

getcharacterlist 6 {
	response {
		#(uuid) is optional, means character_overview.uuid is main index.
		character 0 : *character_overview(uuid)
	}
}
