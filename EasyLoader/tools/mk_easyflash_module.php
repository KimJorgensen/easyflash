<?php

$BASE_PATH = '/Users/alx/Develop/6502-asm/EasyFlash/PROGS/';

/*
** CARTRIDGES / FILES TO LOAD
*/

$more_crt8 = array(
	'pitfall-1984-activision-.crt',
	'c64-diagnostic-rev-586220-19xx-commodore-max-machine-.crt',
	'fraction-fever-1983-spinnaker-software-a-.crt',
	'juke-box-1984-spinnaker-software-a-.crt',
/*
	'save-new-york-1983-creative-software-a-.crt',
	'sea-speller-1984-fisher-price-.crt',
	'space-action-1983-handic-software-.crt',
	'space-action-1983-handic-software-a-.crt',
	'space-ric-o-shay-1983-m.-computer-a-.crt',
	'space-ric-o-shay-1983-m.-computer-a2-.crt',
	'speeddos-copy-rom-19xx-.crt',
	'spitball-1983-creative-software-.crt',
	'star-post-1983-commodore-.crt',
	'stix-19xx-.crt',
	'super-hardcopy-modul-19xx-.crt',
	'super-sketch-1984-personal-peripherals-.crt',
	'super-smash-1983-commodore-.crt',
*/
);

$more_crt8u = array(
	'wizard-of-wor-max-1983-commodore-jp-.crt',
/*
	'sea-wolf-1982-commodore-.crt',
	'speed-math-v.01-1982-commodore-.crt',
	'super-alien-max-1982-commodore-a-.crt',
	'super-alien-v.01-1982-commodore-.crt',
*/
);


$more_crt16 = array(
	'buck-rogers-planet-of-zoom-1983-sega-.crt',
	'choplifter-1982-broderbund-.crt',
	'halftime-battlin-bands-1984-cbs-software-.crt',
	'pole-position-1983-atari-a-.crt',
	'minnesota-fat-s-pool-challenger-1983-hesware-.crt',
	'frogger-ii-threeedeep-1984-parker-brothers-a2-.crt',
	'bridge-64-1983-handic-software-.crt',
	'defender-1983-atari-.crt',
	'rack-em-up-1983-roklan-corp.-.crt',
	'frogger-1983-parker-brothers-a-.crt',
	'gyruss-1984-parker-brothers-.crt',
	'blue-print-1983-commodore-.crt',
	'big-bird-s-special-delivery-1984-children-s-computer-workshop-.crt',
	'toy-bizarre-1984-activision-a-.crt',
	'tank-wars-1983-mr.-computer-.crt',
	'wizard-s-of-id-1983-sierra-online-.crt',
	'movie-musical-madness-1984-cbs-software-.crt',
	'congo-bongo-1983-sega-.crt',
	'ducks-ahoy-1984-cbs-software-.crt',
	'big-bird-s-funhouse-1984-cbs-software-a-.crt',
	'castle-hassle-1983-roklan-.crt',
	'maze-master-1983-hesware-.crt',
	'beamrider-1984-activision-.crt',
/*
	'sammy-lightfoot-1983-sierra-online-.crt',
	'save-new-york-1983-creative-software-.crt',
	'seafox-1982-broderbund-.crt',
	'seafox-1982-broderbund-a-.crt',
	'seahorses-1984-joyce-hakansson-associates-.crt',
	'serpentine-1982-broderbund-.crt',
	'serpentine-1982-broderbund-b-.crt',
	'sesame-street-letter-go-round-1984-children-s-computer-workshop-.crt',
	'sesame-street-letter-go-round-1984-children-s-computer-workshop-a-.crt',
	'solar-fox-1983-commodore-.crt',
	'space-ric-o-shay-1983-m.-computer-.crt',
	'space-shuttle-a-journey-into-space-1983-activision-.crt',
	'space-shuttle-a-journey-into-space-1983-activision-a-.crt',
	'spy-hunter-1983-u.s.-gold-.crt',
	'star-ranger-1983-commodore-.crt',
	'star-trek-1983-sega-.crt',
	'star-wars-the-arcade-game-19xx-parker-brothers-.crt',
*/
);

$more_crt16u = array(
);

$more_files = array(
	'p1x3l-pushr.prg',
	'giana_sisters.prg',
	'Flimmer_2000.prg',
//	'vindicators-1990-domark-.crt',
);

$more_m2i = array(
//	'test',
//	'CHECK/$', // $ = one randomly of them
//	'=work/*', // * = all in that dir
//	'=work-buggy-or-unknown/*',
//	'=work-but-kills-330/*',
);

//$mod256k = array('Shadow o.t.Beast', 'shadow-of-the-beast-1990-ocean-software-.crt');
//$mod256k = array('Chase H.Q. 2', 'chase-h.q.-2-1990-ocean-software-.crt');
//$mod256k = array('RoboCop 2', 'robocop-2-1990-ocean-software-.crt');
$mod256k = array('Toki', 'toki-1991-ocean-software-.crt');
















if($argc != 2){
	die("useage: ".$argv[0]." <file>\n");
}
$MODE = $argv[1];

if($MODE == 'build/easyloader_nrm.prg'){
	$MODE = array(0, 0, false, false);
}else if($MODE == 'build/easyloader_ocm.prg'){
	$MODE = array(1, 0, true, true);
}else{
	fail("unknown argument for <mode>: \"".$MODE."\"\n");
}

// $MODE = array(bank loader, bank fs, loader is high, is shadow mode)

$f = file_get_contents('php://stdin');

if(ord($f[0]) != 0x00 || ord($f[1]) != ($MODE[2] ? 0xa0 : 0x80)){
	fail('wrong start address');
}

$f = substr($f, 2);

$size = strlen($f);

/*
  CartridgeHeader

  Byte CartrigeMagic[16];   $00 - $0F 
  Long HeaderSize;          $10 - $13 
  Word Version;             $14 - $15 
  Word HardwareType;        $16 - $17 
  Byte ExROM_Line           $18 
  Byte Game_Line            $19 
  Byte Unused[6];           $1A - $1F 
  Byte CartridgeName[32];   $20 - $3F 
*/
/*
  ChipPacket

  Byte ChipMagic[4];   0x00 - 0x03 
  Long PacketLength;   0x04 - 0x07 
  Word ChipType;       0x08 - 0x09 
  Word Bank;           0x0A - 0x0B 
  Word Address;        0x0C - 0x0D 
  Word Length;         0x0E - 0x0F 
  Byte Data[Length];   0x10 - ...  
*/

echo 'C64 CARTRIDGE   ';
echo pack('N', 0x40);
echo pack('n', 0x0100);
echo pack('n', 32);
echo pack('C', 1); // 1 here to ultimax
echo pack('C', 0);
echo pack('c*', 0, 0, 0, 0, 0, 0);
echo substr(str_pad('ALeX\'s <DOT>CRT Loader', 32, chr(0)), 0, 32);

$bank = $MODE[0] == 32 ? 33 : ($MODE[3] ? 32 : 1);

$DIR = array();

$CHIPS = array(0 => array(), 1 => array());

$CHIPS[$MODE[2] ? 1 : 0][$MODE[0]] = $f;

foreach($more_crt8 AS $file){
	$CHIPS[0][$bank] = substr(file_get_contents($BASE_PATH.'crt/'.$file), -8*1024);
//	$CHIPS[1][$bank] = str_repeat(chr(0), 8*1024);
	
	$DIR[] = array(
		$file,
		$bank,
		0x10,
		8*1024,
	);
	
	$bank++;
}

foreach($more_crt8u AS $file){
//	$CHIPS[0][$bank] = str_repeat(chr(0xf1), 8*1024);
	$CHIPS[1][$bank] = substr(file_get_contents($BASE_PATH.'crt/'.$file), -8*1024);
	
	
	$DIR[] = array(
		$file,
		$bank,
		0x13,
		8*1024,
	);
	
	$bank++;
}

foreach($more_crt16 AS $file){
	$CHIPS[0][$bank] = substr(file_get_contents($BASE_PATH.'crt/'.$file), -16*1024, 8*1024);
	$CHIPS[1][$bank] = substr(file_get_contents($BASE_PATH.'crt/'.$file), -8*1024);

	$DIR[] = array(
		$file,
		$bank,
		0x11,
		16*1024,
	);

	$bank++;
}

foreach($more_crt16u AS $file){
	$CHIPS[0][$bank] = substr(file_get_contents($BASE_PATH.'crt/'.$file), -16*1024, 8*1024);
	$CHIPS[1][$bank] = substr(file_get_contents($BASE_PATH.'crt/'.$file), -8*1024);

	$DIR[] = array(
		$file,
		$bank,
		0x12,
		16*1024,
	);

	$bank++;
}


// add some files
$start = $bank << 14;
$data = '';
foreach($more_files AS $file){
	$d = file_get_contents($BASE_PATH.'prg/'.$file);
	$DIR[] = array(
		$file,
		$start >> 14,
		0x01,
		strlen($d),
		$start & 0x3fff,
	);
	$data .= $d;
	$start += strlen($d);
}

// find *'s
foreach($more_m2i AS $k => $file){
	if(substr($file, -1) == '*'){
		unset($more_m2i[$k]);
$dh = opendir($BASE_PATH.'m2i/'.substr($file, 0, -1));
while($e = readdir($dh)){
	if($e[0] != '.') // no dot-files
		$more_m2i[] = substr($file, 0, -1).$e;
}
closedir($dh);
	}
}
// add some m2i
foreach($more_m2i AS $file){

	if(substr($file, -1) == '$'){
$all_m2i = array();
$dh = opendir($BASE_PATH.'m2i/'.substr($file, 0, -1));
while($e = readdir($dh)){
	if($e[0] != '.') // no dot-files
		$all_m2i[] = substr($file, 0, -1).$e;
}
closedir($dh);

		for(;;){
			shuffle($all_m2i);
			$file = $all_m2i[0];
			$m2i = read_m2i($file);
			for($i=0; ($l=$m2i[$i]) && (strtolower($l[1]) != 'p'); $i++);
			if(filesize($BASE_PATH.'m2i/'.$file.'/'.trim($l[2])) < 21*1024)
				break;
		}
	}

	$m2i = read_m2i($file);

	$m2i_dir = '';
	$m2i_data = '';
	$m2i_dir_address = $start;
	$start += (count($m2i)+1)*24;
	foreach($m2i AS $r){
//fail(var_export($r, 1));
		if(strtolower($r[1]) == 'p' || strtolower($r[1]) == 's'){
			// program
			$d = file_get_contents($BASE_PATH.'m2i/'.$file.'/'.trim($r[2]));
			$D = array(
				$r[3],
				$start >> 14,
				0x01,
				strlen($d),
				$start & 0x3fff
			);
			$start += strlen($d);
			$m2i_data .= $d;
		}else{
			// deleted
			$D = array(
				$r[3],
				0,
				0x03,
				0,
				0
			);
		}
		$m2i_dir .= (str_pad(rtrim(substr($D[0], 0, 16)), 16, chr(0))); // name
		$m2i_dir .= chr($D[2]); // type
		$m2i_dir .= chr($D[1]); // bank
		$m2i_dir .= pack('v', $D[4]); // offset, unused for crt
		$m2i_dir .= substr(pack('V', $D[3]), 0, 3); // size (encode 32, take 24)
		$m2i_dir .= chr(0x00); // pad
	}
	
	$m2i_dir .= str_repeat(chr(0xff), 24); // end of dir marker
	$m2i_dir .= $m2i_data; // attach files
	
	file_put_contents('php://stderr', sprintf('m2i file %s at bank $%02x addr $%04x', $file, $m2i_dir_address >> 14, 0x8000+($m2i_dir_address & 0x3fff))."\n");

	$DIR[] = array(
		basename($file),
		$m2i_dir_address >> 14,
		0x02,
		strlen($m2i_dir),
		$m2i_dir_address & 0x3fff,
	);
	$data .= $m2i_dir;
}

for($o=0; $o<strlen($data); $o+=16*1024){
	$CHIPS[0][$bank] = substr($data, $o       , 8*1024);
	$CHIPS[1][$bank] = substr($data, $o+8*1024, 8*1024);
	$bank++;
}

if($bank > 64){
	fail("bank to big: ".$bank."\n");
}

if($MODE[3]){
	$DIR[] = array(
		$mod256k[0],
		0,
		0x11,
		256*1024, // wird aber als 16k ausgegeben (s. typ)
	);
	$f = fopen($BASE_PATH.'crt-bad/'.$mod256k[1], 'r');
	fread($f, 64); // skip crt header
	for($i=0; $i<32; $i++){
		fread($f, 16); // skip chip header
		$CHIPS[$i >> 4][$i] = fread($f, 8*1024);
	}
}

// CREATE DIR

$dir = '';
foreach($DIR AS $D){
	$dir .= repair_case(str_pad(rtrim(substr($D[0], 0, 16)), 16, chr(0))); // name
	$dir .= chr($D[2]); // type
	$dir .= chr($D[1]); // bank
	$dir .= chr(0x00); // pad
	$dir .= pack('v', $D[4]); // offset, unused for crt
	$dir .= substr(pack('V', $D[3]), 0, 3); // size (encode 32, take 24)
}

// padding with 255 means also type 255 = EOF
$dir = str_pad($dir, 8*1024, chr(0xff));

//if($MODE[3]){
	$ult = ultimax_loader($MODE[0], $MODE[2]);
	if($MODE[1] == 0){
		$dir = substr($dir, 0, 8*1024 - strlen($ult)).$ult;
	}else{
		$CHIPS[1][0] = str_pad($ult, 8*1024, chr(0), STR_PAD_LEFT);
	}
//}

$CHIPS[1][$MODE[1]] = $dir;


ksort($CHIPS[0]);
foreach($CHIPS[0] AS $i => $dummy){
	echo 'CHIP';
	echo pack('N', 0x10 + 8*1024);
	echo pack('n', 0x0000);
	echo pack('n', $i);
	echo pack('n', 0x8000);
	echo pack('n', 8*1024);
	echo str_pad(substr($CHIPS[0][$i], 0, 8*1024), 8*1024);
}
ksort($CHIPS[1]);
foreach($CHIPS[1] AS $i => $dummy){
	echo 'CHIP';
	echo pack('N', 0x10 + 8*1024);
	echo pack('n', 0x0000);
	echo pack('n', $i);
	echo pack('n', 0xa000);
	echo pack('n', 8*1024);
	echo str_pad(substr($CHIPS[1][$i], 0, 8*1024), 8*1024);
}

function repair_case($t){
	for($i=0; $i<strlen($t); $i++){
		$o = ord($t[$i]);
		if($o >= 0x41 && $o <= 0x5a){
			$t[$i] = chr($o + 0x20);
		}else if($o >= 0x61 && $o <= 0x7a){
			$t[$i] = chr($o - 0x20);
		}
		if($o >= 0xc1 && $o <= 0xda){
			$t[$i] = chr($o + 0x20);
		}else if($o >= 0xe1 && $o <= 0xfa){
			$t[$i] = chr($o - 0x20);
		}
	}
	return $t;
}

function ultimax_loader($bank, $hiaddr){
	return chr($bank).chr(0x07).substr(file_get_contents('tools/skoe_startup.bin'), 2);
/*
	return 
		chr($bank).						// constant $01
		chr(0x8d).chr(0x00).chr(0xde).	// STA $DE00
		chr(0xa9).chr(0x07). 			// LDA #$07 // MODE_16k
		chr(0x8d).chr(0x02).chr(0xde).	// STA $DE02
		chr(0x6c).chr(0x00).chr($hiaddr ? 0xa0 : 0x80). // JMP ($addr)
		chr(0xa2).chr(0x0b). 			// LDX #$0b
		chr(0x95).chr(0x02). 			// STA $02,X
		chr(0xbd).chr(0xe5).chr(0xff).	// LDA $FFE5,X
		chr(0xca). 						// DEX
		chr(0x10).chr(0xf8). 			// BPL $FFF3
		chr(0x0c).chr(0xf1).chr(0xff).	// NOOP $FFF1
			// FFF1 = RESET ADDRESS
		chr(0xea).			 			// NOP
		chr(0x0c).			 			// NOOP $XXXX
			// JUMPS OVER $00,$01
		'';
*/
}

function fail($text){
	file_put_contents('php://stderr', $text."\n");
	exit(1);
}

function read_m2i($file){
	$dh = opendir($BASE_PATH.'m2i/'.$file.'/');
	while(($m = readdir($dh)) !== false){
		if(strlen($m) > 4 && substr(strtolower($m), -4) == '.m2i')
			break;
	}

	if($m === false){
		fail('unable to find a m2i: '.$file);
	}

	$m2i = split("[\r\n]+", file_get_contents($BASE_PATH.'m2i/'.$file.'/'.$m));
	array_shift($m2i); // drop first line
	foreach($m2i AS $k => $v){
		if(trim($v) == ''){
			unset($m2i[$k]);
		}
	}
	$RET = array();
	foreach($m2i AS $ln){
		if(!preg_match('!^([pds]):([^:]*):(.*)$!i', $ln, $r)){
			fail('umable to decode '.var_export($ln, 1));
		}
		$RET[] = $r;
	}
	return $RET;
}

?>