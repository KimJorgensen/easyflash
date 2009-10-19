<?php

	echo 'build/'.substr($argv[1], 0, -3).'prg: '.implode(' ', mkdep($argv[1]))."\n";

	function mkdep($src){
		if(!is_file($src))
			return array();
		
		$file = file_get_contents($src);

		if(! preg_match_all('!.*\.import [a-z0-9]+ "(.*?)"!', $file, $M, PREG_SET_ORDER))
			return array();

		$deps = array();
		foreach($M as $ln){
			if(strpos($ln[0], '//') === false)
				$deps = array_merge($deps, array($ln[1]), mkdep($ln[1]));
		}
		
		return $deps;
	}
	