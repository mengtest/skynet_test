.package {
	type 0 : integer
	session 1 : integer
	ud 2 : string
}

.character_pos{
	x 0 : integer
	y 1 : integer
	z 2 : integer
}

.character_info{
	name 0 : string
	tempid 1 : integer
	job 2 : integer
	sex 3 : integer
	level 4 : integer
	pos 5 : character_pos
}

heartbeat 1 {}

subid 2 {
	request {
		result 0 : string
	}
}

characterupdate 3 {
	request {
		info 0 : character_info
	}
}
