.package {
	type 0 : integer
	session 1 : integer
	ud 2 : string
}

ping 1 {
	request {
		userid 0 : string
	}
	response {
		ok 0 : boolean
	}
}

signup 2 {
	request {
		userid 0 : string
	}
	response {
		ok 0 : boolean
	}
}

signin 3 {
	request {
		userid 0 : string
	}
	response {
		ok 0 : boolean
	}
}

login 4 {
	response {
		ok 0 : boolean
	}
}