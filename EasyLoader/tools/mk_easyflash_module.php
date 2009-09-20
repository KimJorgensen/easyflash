<?php

if($argc != 3){
	fail("usage: ".$argv[0]." <file> <package>\n");
}
$MODE = $argv[1];

if($MODE == 'build/easyloader_nrm.prg'){
	$MODE = array(0, 0, false, false);
}else if($MODE == 'build/easyloader_ocm.prg'){
	$MODE = array(1, 0, true, true);
}else{
	fail("unknown argument for <file>: \"".$MODE."\"\n");
}

// $MODE = array(bank loader, bank fs, loader is high, is shadow mode)

$f = file_get_contents('php://stdin');

if(ord($f[0]) != 0x00 || ord($f[1]) != ($MODE[2] ? 0xa0 : 0x80)){
	fail('wrong start address');
}

$f = substr($f, 2);

$size = strlen($f);


/* collect files! */
$BASE_PATH = dirname($argv[2]).'/';
$config = array(
	'strip_extension' => 0,
);

$more_crt8 = array();
$more_crt8u = array();
$more_crt16 = array();
$more_crt16u = array();
$more_files = array();
$more_m2i = array();
$mod256k = array();

foreach(split("[\r\n]+", file_get_contents($argv[2])) AS $ln){
	if(trim($ln) == '' || substr(trim($ln), 0, 1) == '#'){
		// empty line or comment -> skip line
		continue;
	}
	if(!preg_match('!^(.*):(.*?)(=(.*))?$!', $ln, $match)){
		fail('bad package syntax: '.$ln);
	}
	$mode = $match[1];
	$file = $match[2];
	$name = isset($match[4]) ? $match[4] : '';

	if($mode == 'cfg'){
		$config[$file] = trim($name);
	}else{
		if($name == ''){
			$name = basename($file);
			if($config['strip_extension']){
				$name = substr($name, 0, -4);
			}else{
				$name = $name;
			}
		}
		if($file[0] != '/'){
			// file is relative -> prepend base path
			$file = $BASE_PATH.$file;
		}
		switch($mode){
		case 'p':
		case 'prg':
			$more_files[$file] = $name;
			break;
		case '8':
		case '8k':
			$more_crt8[$file] = $name;
			break;
		case '16':
		case '16k':
			$more_crt16[$file] = $name;
			break;
		case 'm8':
		case 'm8k':
			$more_crt8u[$file] = $name;
			break;
		case 'm16':
		case 'm16k':
			$more_crt16u[$file] = $name;
			break;
		case 'ocean':
			$mod256k = array($name, $file);
			break;
//		case 'm2i':
//			$more_m2i[$name] = $file;
//			break;
		}
	}
}

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

$o_banks = ceil((filesize($mod256k[1])-64) / (0x2000 + 16));
$bank = $MODE[3] ? $o_banks : 1;

$DIR = array();

$CHIPS = array(0 => array(), 1 => array());

$CHIPS[$MODE[2] ? 1 : 0][$MODE[0]] = $f;

foreach($more_crt8 AS $file => $name){
	$CHIPS[0][$bank] = substr(file_get_contents($file), -8*1024);
//	$CHIPS[1][$bank] = str_repeat(chr(0), 8*1024);
	
	$DIR[] = array(
		$name,
		$bank,
		0x10,
		8*1024,
	);
	
	$bank++;
}

foreach($more_crt8u AS $file => $name){
//	$CHIPS[0][$bank] = str_repeat(chr(0xf1), 8*1024);
	$CHIPS[1][$bank] = substr(file_get_contents($file), -8*1024);
	
	
	$DIR[] = array(
		$name,
		$bank,
		0x13,
		8*1024,
	);
	
	$bank++;
}

foreach($more_crt16 AS $file => $name){
	$CHIPS[0][$bank] = substr(file_get_contents($file), -16*1024, 8*1024);
	$CHIPS[1][$bank] = substr(file_get_contents($file), -8*1024);

	$DIR[] = array(
		$name,
		$bank,
		0x11,
		16*1024,
	);

	$bank++;
}

foreach($more_crt16u AS $file => $name){
	$CHIPS[0][$bank] = substr(file_get_contents($file), -16*1024, 8*1024);
	$CHIPS[1][$bank] = substr(file_get_contents($file), -8*1024);

	$DIR[] = array(
		$name,
		$bank,
		0x12,
		16*1024,
	);

	$bank++;
}


// add some files
$start = $bank << 14;
$data = '';
foreach($more_files AS $file => $name){
	$d = file_get_contents($file);
	if(substr($d, 0, 8) == 'C64File'.chr(0)){
		// found a P00 file -> chop header
		$d = substr($d, 26);
	}
	$DIR[] = array(
		$name,
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
$dh = opendir(substr($file, 0, -1));
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
$dh = opendir(substr($file, 0, -1));
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
			if(filesize($file.'/'.trim($l[2])) < 21*1024)
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
			$d = file_get_contents($file.'/'.trim($r[2]));
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
		$o_banks*0x2000,
	);
	$f = fopen($mod256k[1], 'r');
	fread($f, 64); // skip crt header
	for($i=0; $i<$o_banks; $i++){
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

file_put_contents('php://stderr', (64-$bank)." blocks free\n");


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
	if($bank == 0 && !$hiaddr){
		return file_get_contents('tools/easyloader_launcher_nrm.bin');
	}else if($bank == 1 && $hiaddr){
		return file_get_contents('tools/easyloader_launcher_ocm.bin');
	}else{
		fail('unallowed bank/offset combination');
	}
}

function fail($text){
	file_put_contents('php://stderr', $text."\n");
	exit(1);
}

function read_m2i($file){
	$dh = opendir($file.'/');
	while(($m = readdir($dh)) !== false){
		if(strlen($m) > 4 && substr(strtolower($m), -4) == '.m2i')
			break;
	}

	if($m === false){
		fail('unable to find a m2i: '.$file);
	}

	$m2i = split("[\r\n]+", file_get_contents($file.'/'.$m));
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