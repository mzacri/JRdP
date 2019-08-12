set test 1.0;
proc fonction {} {
	uplevel 1 {
		set req2 [demo::Move -s 1.0 &]
	}
	
}
