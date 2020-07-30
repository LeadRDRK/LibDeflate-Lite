--[[--
LibDeflate 1.0.2-lite <br>
Pure Lua DEFLATE/zlib decompressor.

@file LibDeflate.lua
@author Haoqian He (Github: SafeteeWoW; World of Warcraft: Safetyy-Illidan(US))
@copyright LibDeflate <2018-2020> Haoqian He
@license zlib License

This library is implemented according to the following specifications. <br>
Report a bug if LibDeflate is not fully compliant with those specs. <br>
Both compressors and decompressors have been implemented in the library.<br>
1. RFC1950: DEFLATE Compressed Data Format Specification version 1.3 <br>
https://tools.ietf.org/html/rfc1951 <br>
2. RFC1951: ZLIB Compressed Data Format Specification version 3.3 <br>
https://tools.ietf.org/html/rfc1950 <br>

This library requires Lua 5.1/5.2/5.3/5.4 interpreter or LuaJIT v2.0+. <br>
This library does not have any dependencies. <br>
<br>
This file "LibDeflate.lua" is the only source file of
the library. <br>
Submit suggestions or report bugs to
https://github.com/safeteeWow/LibDeflate/issues
]]

--[[
zlib License

(C) 2018-2020 Haoqian He

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

License History:
1. GNU General Public License Version 3 in v1.0.0 and earlier versions.
2. GNU Lesser General Public License Version 3 in v1.0.1
3. the zlib License since v1.0.2

Credits and Disclaimer:
This library rewrites the code from the algorithm
and the ideas of the following projects,
and uses their code to help to test the correctness of this library,
but their code is not included directly in the library itself.
Their original licenses shall be comply when used.

1. zlib, by Jean-loup Gailly (compression) and Mark Adler (decompression).
	http://www.zlib.net/
	Licensed under zlib License. http://www.zlib.net/zlib_license.html
	For the compression algorithm.
2. puff, by Mark Adler. https://github.com/madler/zlib/tree/master/contrib/puff
	Licensed under zlib License. http://www.zlib.net/zlib_license.html
	For the decompression algorithm.
3. LibCompress, by jjsheets and Galmok of European Stormrage (Horde)
	https://www.wowace.com/projects/libcompress
	Licensed under GPLv2.
	https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
	For the code to create customized codec.
4. WeakAuras2,
	https://github.com/WeakAuras/WeakAuras2
	Licensed under GPLv2.
	For the 6bit encoding and decoding.
]]

--[[
	Curseforge auto-packaging replacements:

	Project Date: @project-date-iso@
	Project Hash: @project-hash@
	Project Version: @project-version@
--]]

local LibDeflate

do
	-- Semantic version. all lowercase.
	-- Suffix can be alpha1, alpha2, beta1, beta2, rc1, rc2, etc.
	-- NOTE: Two version numbers needs to modify.
	-- 1. On the top of LibDeflate.lua
	-- 2. _VERSION
	-- 3. _MINOR

	-- version to store the official version of LibDeflate
	local _VERSION = "1.0.2-lite"

	-- When MAJOR is changed, I should name it as LibDeflate2
	local _MAJOR = "LibDeflate"

	-- Update this whenever a new version, for LibStub version registration.
	-- 0 : v0.x
	-- 1 : v1.0.0
	-- 2 : v1.0.1
	-- 3 : v1.0.2
	local _MINOR = 3

	local _COPYRIGHT =
	"LibDeflate ".._VERSION
	.." Copyright (C) 2018-2020 Haoqian He."
	.." Licensed under the zlib License"

	-- Register in the World of Warcraft library "LibStub" if detected.
	if LibStub then
		local lib, minor = LibStub:GetLibrary(_MAJOR, true)
		if lib and minor and minor >= _MINOR then -- No need to update.
			return lib
		else -- Update or first time register
			LibDeflate = LibStub:NewLibrary(_MAJOR, _MINOR)
			-- NOTE: It is important that new version has implemented
			-- all exported APIs and tables in the old version,
			-- so the old library is fully garbage collected,
			-- and we 100% ensure the backward compatibility.
		end
	else -- "LibStub" is not detected.
		LibDeflate = {}
	end

	LibDeflate._VERSION = _VERSION
	LibDeflate._MAJOR = _MAJOR
	LibDeflate._MINOR = _MINOR
	LibDeflate._COPYRIGHT = _COPYRIGHT
end

-- localize Lua api for faster access.
local assert = assert
local error = error
local pairs = pairs
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local table_concat = table.concat
local table_sort = table.sort
local tostring = tostring
local type = type

-- Converts i to 2^i, (0<=i<=32)
-- This is used to implement bit left shift and bit right shift.
-- "x >> y" in C:   "(x-x%_pow2[y])/_pow2[y]" in Lua
-- "x << y" in C:   "x*_pow2[y]" in Lua
local _pow2 = {}

-- Converts any byte to a character, (0<=byte<=255)
local _byte_to_char = {}

-- _reverseBitsTbl[len][val] stores the bit reverse of
-- the number with bit length "len" and value "val"
-- For example, decimal number 6 with bits length 5 is binary 00110
-- It's reverse is binary 01100,
-- which is decimal 12 and 12 == _reverseBitsTbl[5][6]
-- 1<=len<=9, 0<=val<=2^len-1
-- The reason for 1<=len<=9 is that the max of min bitlen of huffman code
-- of a huffman alphabet is 9?
local _reverse_bits_tbl = {}

-- Convert a literal/LZ77_length deflate code to LZ77 base length
-- The key of the table is (code - 256), 257<=code<=285
local _literal_deflate_code_to_base_len = {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
	35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
}

-- Convert a literal/LZ77_length deflate code to base LZ77 length extra bits
-- The key of the table is (code - 256), 257<=code<=285
local _literal_deflate_code_to_extra_bitlen = {
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
	3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
}

-- Convert a distance deflate code to base LZ77 distance. (0<=code<=29)
local _dist_deflate_code_to_base_dist = {
	[0] = 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
	257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
	8193, 12289, 16385, 24577,
}

-- Convert a distance deflate code to LZ77 bits length. (0<=code<=29)
local _dist_deflate_code_to_extra_bitlen = {
	[0] = 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
	7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
}

-- The code order of the first huffman header in the dynamic deflate block.
-- See the page 12 of RFC1951
local _rle_codes_huffman_bitlen_order = {16, 17, 18,
	0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
}

-- The following tables are used by fixed deflate block.
-- The value of these tables are assigned at the bottom of the source.

-- Convert huffman code of the literal/LZ77_length to deflate codes,
-- in fixed deflate block.
local _fix_block_literal_huffman_to_deflate_code

-- The count of each bit length of the literal/LZ77_length deflate codes,
-- in fixed deflate block.
local _fix_block_literal_huffman_bitlen_count

-- Convert huffman code of the distance to deflate codes,
-- in fixed deflate block.
local _fix_block_dist_huffman_to_deflate_code

-- The count of each bit length of the huffman code of
-- the distance deflate codes,
-- in fixed deflate block.
local _fix_block_dist_huffman_bitlen_count

for i = 0, 255 do
	_byte_to_char[i] = string_char(i)
end

do
	local pow = 1
	for i = 0, 32 do
		_pow2[i] = pow
		pow = pow * 2
	end
end

for i = 1, 9 do
	_reverse_bits_tbl[i] = {}
	for j=0, _pow2[i+1]-1 do
		local reverse = 0
		local value = j
		for _ = 1, i do
			-- The following line is equivalent to "res | (code %2)" in C.
			reverse = reverse - reverse%2
				+ (((reverse%2==1) or (value % 2) == 1) and 1 or 0)
			value = (value-value%2)/2
			reverse = reverse * 2
		end
		_reverse_bits_tbl[i][j] = (reverse-reverse%2)/2
	end
end

--- Calculate the Adler-32 checksum of the string. <br>
-- See RFC1950 Page 9 https://tools.ietf.org/html/rfc1950 for the
-- definition of Adler-32 checksum.
-- @param str [string] the input string to calcuate its Adler-32 checksum.
-- @return [integer] The Adler-32 checksum, which is greater or equal to 0,
-- and less than 2^32 (4294967296).
function LibDeflate:Adler32(str)
	-- This function is loop unrolled by better performance.
	--
	-- Here is the minimum code:
	--
	-- local a = 1
	-- local b = 0
	-- for i=1, #str do
	-- 		local s = string.byte(str, i, i)
	-- 		a = (a+s)%65521
	-- 		b = (b+a)%65521
	-- 		end
	-- return b*65536+a
	if type(str) ~= "string" then
		error(("Usage: LibDeflate:Adler32(str):"
			.." 'str' - string expected got '%s'."):format(type(str)), 2)
	end
	local strlen = #str

	local i = 1
	local a = 1
	local b = 0
	while i <= strlen - 15 do
		local x1, x2, x3, x4, x5, x6, x7, x8,
			x9, x10, x11, x12, x13, x14, x15, x16 = string_byte(str, i, i+15)
		b = (b+16*a+16*x1+15*x2+14*x3+13*x4+12*x5+11*x6+10*x7+9*x8+8*x9
			+7*x10+6*x11+5*x12+4*x13+3*x14+2*x15+x16)%65521
		a = (a+x1+x2+x3+x4+x5+x6+x7+x8+x9+x10+x11+x12+x13+x14+x15+x16)%65521
		i =  i + 16
	end
	while (i <= strlen) do
		local x = string_byte(str, i, i)
		a = (a + x) % 65521
		b = (b + a) % 65521
		i = i + 1
	end
	return (b*65536+a) % 4294967296
end

-- Compare adler32 checksum.
-- adler32 should be compared with a mod to avoid sign problem
-- 4072834167 (unsigned) is the same adler32 as -222133129
local function IsEqualAdler32(actual, expected)
	return (actual % 4294967296) == (expected % 4294967296)
end

--- Create a preset dictionary.
--
-- This function is not fast, and the memory consumption of the produced
-- dictionary is about 50 times of the input string. Therefore, it is suggestted
-- to run this function only once in your program.
--
-- It is very important to know that if you do use a preset dictionary,
-- compressors and decompressors MUST USE THE SAME dictionary. That is,
-- dictionary must be created using the same string. If you update your program
-- with a new dictionary, people with the old version won't be able to transmit
-- data with people with the new version. Therefore, changing the dictionary
-- must be very careful.
--
-- The parameters "strlen" and "adler32" add a layer of verification to ensure
-- the parameter "str" is not modified unintentionally during the program
-- development.
--
-- @usage local dict_str = "1234567890"
--
-- -- print(dict_str:len(), LibDeflate:Adler32(dict_str))
-- -- Hardcode the print result below to verify it to avoid acciently
-- -- modification of 'str' during the program development.
-- -- string length: 10, Adler-32: 187433486,
-- -- Don't calculate string length and its Adler-32 at run-time.
--
-- local dict = LibDeflate:CreateDictionary(dict_str, 10, 187433486)
--
-- @param str [string] The string used as the preset dictionary. <br>
-- You should put stuffs that frequently appears in the dictionary
-- string and preferablely put more frequently appeared stuffs toward the end
-- of the string. <br>
-- Empty string and string longer than 32768 bytes are not allowed.
-- @param strlen [integer] The length of 'str'. Please pass in this parameter
-- as a hardcoded constant, in order to verify the content of 'str'. The value
-- of this parameter should be known before your program runs.
-- @param adler32 [integer] The Adler-32 checksum of 'str'. Please pass in this
-- parameter as a hardcoded constant, in order to verify the content of 'str'.
-- The value of this parameter should be known before your program runs.
-- @return  [table] The dictionary used for preset dictionary compression and
-- decompression.
-- @raise error if 'strlen' does not match the length of 'str',
-- or if 'adler32' does not match the Adler-32 checksum of 'str'.
function LibDeflate:CreateDictionary(str, strlen, adler32)
	if type(str) ~= "string" then
		error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):"
			.." 'str' - string expected got '%s'."):format(type(str)), 2)
	end
	if type(strlen) ~= "number" then
		error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):"
			.." 'strlen' - number expected got '%s'."):format(
			type(strlen)), 2)
	end
	if type(adler32) ~= "number" then
		error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):"
			.." 'adler32' - number expected got '%s'."):format(
			type(adler32)), 2)
	end
	if strlen ~= #str then
		error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):"
				.." 'strlen' does not match the actual length of 'str'."
				.." 'strlen': %u, '#str': %u ."
				.." Please check if 'str' is modified unintentionally.")
			:format(strlen, #str))
	end
	if strlen == 0 then
		error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):"
			.." 'str' - Empty string is not allowed."), 2)
	end
	if strlen > 32768 then
		error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):"
			.." 'str' - string longer than 32768 bytes is not allowed."
			 .." Got %d bytes."):format(strlen), 2)
	end
	local actual_adler32 = self:Adler32(str)
	if not IsEqualAdler32(adler32, actual_adler32) then
		error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):"
				.." 'adler32' does not match the actual adler32 of 'str'."
				.." 'adler32': %u, 'Adler32(str)': %u ."
				.." Please check if 'str' is modified unintentionally.")
			:format(adler32, actual_adler32))
	end

	local dictionary = {}
	dictionary.adler32 = adler32
	dictionary.hash_tables = {}
	dictionary.string_table = {}
	dictionary.strlen = strlen
	local string_table = dictionary.string_table
	local hash_tables = dictionary.hash_tables
	string_table[1] = string_byte(str, 1, 1)
	string_table[2] = string_byte(str, 2, 2)
	if strlen >= 3 then
		local i = 1
		local hash = string_table[1]*256+string_table[2]
		while i <= strlen - 2 - 3 do
			local x1, x2, x3, x4 = string_byte(str, i+2, i+5)
			string_table[i+2] = x1
			string_table[i+3] = x2
			string_table[i+4] = x3
			string_table[i+5] = x4
			hash = (hash*256+x1)%16777216
			local t = hash_tables[hash]
			if not t then t = {}; hash_tables[hash] = t end
			t[#t+1] = i-strlen
			i = i + 1
			hash = (hash*256+x2)%16777216
			t = hash_tables[hash]
			if not t then t = {}; hash_tables[hash] = t end
			t[#t+1] = i-strlen
			i = i + 1
			hash = (hash*256+x3)%16777216
			t = hash_tables[hash]
			if not t then t = {}; hash_tables[hash] = t end
			t[#t+1] = i-strlen
			i = i + 1
			hash = (hash*256+x4)%16777216
			t = hash_tables[hash]
			if not t then t = {}; hash_tables[hash] = t end
			t[#t+1] = i-strlen
			i = i + 1
		end
		while i <= strlen - 2 do
			local x = string_byte(str, i+2)
			string_table[i+2] = x
			hash = (hash*256+x)%16777216
			local t = hash_tables[hash]
			if not t then t = {}; hash_tables[hash] = t end
			t[#t+1] = i-strlen
			i = i + 1
		end
	end
	return dictionary
end

-- Check if the dictionary is valid.
-- @param dictionary The preset dictionary for compression and decompression.
-- @return true if valid, false if not valid.
-- @return if not valid, the error message.
local function IsValidDictionary(dictionary)
	if type(dictionary) ~= "table" then
		return false, ("'dictionary' - table expected got '%s'.")
			:format(type(dictionary))
	end
	if type(dictionary.adler32) ~= "number"
		or type(dictionary.string_table) ~= "table"
		or type(dictionary.strlen) ~= "number"
		or dictionary.strlen <= 0
		or dictionary.strlen > 32768
		or dictionary.strlen ~= #dictionary.string_table
		or type(dictionary.hash_tables) ~= "table"
		then
		return false, ("'dictionary' - corrupted dictionary.")
			:format(type(dictionary))
	end
	return true, ""
end

-- Check if the compression/decompression arguments is valid
-- @param str The input string.
-- @param check_dictionary if true, check if dictionary is valid.
-- @param dictionary The preset dictionary for compression and decompression.
-- @param check_configs if true, check if config is valid.
-- @param configs The compression configuration table
-- @return true if valid, false if not valid.
-- @return if not valid, the error message.
local function IsValidArguments(str,
	check_dictionary, dictionary,
	check_configs, configs)

	if type(str) ~= "string" then
		return false,
			("'str' - string expected got '%s'."):format(type(str))
	end
	if check_dictionary then
		local dict_valid, dict_err = IsValidDictionary(dictionary)
		if not dict_valid then
			return false, dict_err
		end
	end
	if check_configs then
		local type_configs = type(configs)
		if type_configs ~= "nil" and type_configs ~= "table" then
			return false,
			("'configs' - nil or table expected got '%s'.")
				:format(type(configs))
		end
		if type_configs == "table" then
			for k, v in pairs(configs) do
				if k ~= "level" and k ~= "strategy" then
					return false,
					("'configs' - unsupported table key in the configs: '%s'.")
					:format(k)
				elseif k == "level" and not _compression_level_configs[v] then
					return false,
					("'configs' - unsupported 'level': %s."):format(tostring(v))
				elseif k == "strategy" and v ~= "fixed" and v ~= "huffman_only"
						and v ~= "dynamic" then
						-- random_block_type is for testing purpose
					return false, ("'configs' - unsupported 'strategy': '%s'.")
						:format(tostring(v))
				end
			end
		end
	end
	return true, ""
end

--[[ --------------------------------------------------------------------------
	Decompress code
--]] --------------------------------------------------------------------------

--[[
	Create a reader to easily reader stuffs as the unit of bits.
	Return values:
	1. ReadBits(bitlen)
	2. ReadBytes(bytelen, buffer, buffer_size)
	3. Decode(huffman_bitlen_count, huffman_symbol, min_bitlen)
	4. ReaderBitlenLeft()
	5. SkipToByteBoundary()
--]]
local function CreateReader(input_string)
	local input = input_string
	local input_strlen = #input_string
	local input_next_byte_pos = 1
	local cache_bitlen = 0
	local cache = 0

	-- Read some bits.
	-- To improve speed, this function does not
	-- check if the input has been exhausted.
	-- Use ReaderBitlenLeft() < 0 to check it.
	-- @param bitlen the number of bits to read
	-- @return the data is read.
	local function ReadBits(bitlen)
		local rshift_mask = _pow2[bitlen]
		local code
		if bitlen <= cache_bitlen then
			code = cache % rshift_mask
			cache = (cache - code) / rshift_mask
			cache_bitlen = cache_bitlen - bitlen
		else -- Whether input has been exhausted is not checked.
			local lshift_mask = _pow2[cache_bitlen]
			local byte1, byte2, byte3, byte4 = string_byte(input
				, input_next_byte_pos, input_next_byte_pos+3)
			-- This requires lua number to be at least double ()
			cache = cache + ((byte1 or 0)+(byte2 or 0)*256
				+ (byte3 or 0)*65536+(byte4 or 0)*16777216)*lshift_mask
			input_next_byte_pos = input_next_byte_pos + 4
			cache_bitlen = cache_bitlen + 32 - bitlen
			code = cache % rshift_mask
			cache = (cache - code) / rshift_mask
		end
		return code
	end

	-- Read some bytes from the reader.
	-- Assume reader is on the byte boundary.
	-- @param bytelen The number of bytes to be read.
	-- @param buffer The byte read will be stored into this buffer.
	-- @param buffer_size The buffer will be modified starting from
	--	buffer[buffer_size+1], ending at buffer[buffer_size+bytelen-1]
	-- @return the new buffer_size
	local function ReadBytes(bytelen, buffer, buffer_size)
		assert(cache_bitlen % 8 == 0)

		local byte_from_cache = (cache_bitlen/8 < bytelen)
			and (cache_bitlen/8) or bytelen
		for _=1, byte_from_cache do
			local byte = cache % 256
			buffer_size = buffer_size + 1
			buffer[buffer_size] = string_char(byte)
			cache = (cache - byte) / 256
		end
		cache_bitlen = cache_bitlen - byte_from_cache*8
		bytelen = bytelen - byte_from_cache
		if (input_strlen - input_next_byte_pos - bytelen + 1) * 8
			+ cache_bitlen < 0 then
			return -1 -- out of input
		end
		for i=input_next_byte_pos, input_next_byte_pos+bytelen-1 do
			buffer_size = buffer_size + 1
			buffer[buffer_size] = string_sub(input, i, i)
		end

		input_next_byte_pos = input_next_byte_pos + bytelen
		return buffer_size
	end

	-- Decode huffman code
	-- To improve speed, this function does not check
	-- if the input has been exhausted.
	-- Use ReaderBitlenLeft() < 0 to check it.
	-- Credits for Mark Adler. This code is from puff:Decode()
	-- @see puff:Decode(...)
	-- @param huffman_bitlen_count
	-- @param huffman_symbol
	-- @param min_bitlen The minimum huffman bit length of all symbols
	-- @return The decoded deflate code.
	--	Negative value is returned if decoding fails.
	local function Decode(huffman_bitlen_counts, huffman_symbols, min_bitlen)
		local code = 0
		local first = 0
		local index = 0
		local count
		if min_bitlen > 0 then
			if cache_bitlen < 15 and input then
				local lshift_mask = _pow2[cache_bitlen]
				local byte1, byte2, byte3, byte4 =
					string_byte(input, input_next_byte_pos
					, input_next_byte_pos+3)
				-- This requires lua number to be at least double ()
				cache = cache + ((byte1 or 0)+(byte2 or 0)*256
					+(byte3 or 0)*65536+(byte4 or 0)*16777216)*lshift_mask
				input_next_byte_pos = input_next_byte_pos + 4
				cache_bitlen = cache_bitlen + 32
			end

			local rshift_mask = _pow2[min_bitlen]
			cache_bitlen = cache_bitlen - min_bitlen
			code = cache % rshift_mask
			cache = (cache - code) / rshift_mask
			-- Reverse the bits
			code = _reverse_bits_tbl[min_bitlen][code]

			count = huffman_bitlen_counts[min_bitlen]
			if code < count then
				return huffman_symbols[code]
			end
			index = count
			first = count * 2
			code = code * 2
		end

		for bitlen = min_bitlen+1, 15 do
			local bit
			bit = cache % 2
			cache = (cache - bit) / 2
			cache_bitlen = cache_bitlen - 1

			code = (bit==1) and (code + 1 - code % 2) or code
			count = huffman_bitlen_counts[bitlen] or 0
			local diff = code - first
			if diff < count then
				return huffman_symbols[index + diff]
			end
			index = index + count
			first = first + count
			first = first * 2
			code = code * 2
		end
		-- invalid literal/length or distance code
		-- in fixed or dynamic block (run out of code)
		return -10
	end

	local function ReaderBitlenLeft()
		return (input_strlen - input_next_byte_pos + 1) * 8 + cache_bitlen
	end

	local function SkipToByteBoundary()
		local skipped_bitlen = cache_bitlen%8
		local rshift_mask = _pow2[skipped_bitlen]
		cache_bitlen = cache_bitlen - skipped_bitlen
		cache = (cache - cache % rshift_mask) / rshift_mask
	end

	return ReadBits, ReadBytes, Decode, ReaderBitlenLeft, SkipToByteBoundary
end

-- Create a deflate state, so I can pass in less arguments to functions.
-- @param str the whole string to be decompressed.
-- @param dictionary The preset dictionary. nil if not provided.
--		This dictionary should be produced by LibDeflate:CreateDictionary(str)
-- @return The decomrpess state.
local function CreateDecompressState(str, dictionary)
	local ReadBits, ReadBytes, Decode, ReaderBitlenLeft
		, SkipToByteBoundary = CreateReader(str)
	local state =
	{
		ReadBits = ReadBits,
		ReadBytes = ReadBytes,
		Decode = Decode,
		ReaderBitlenLeft = ReaderBitlenLeft,
		SkipToByteBoundary = SkipToByteBoundary,
		buffer_size = 0,
		buffer = {},
		result_buffer = {},
		dictionary = dictionary,
	}
	return state
end

-- Get the stuffs needed to decode huffman codes
-- @see puff.c:construct(...)
-- @param huffman_bitlen The huffman bit length of the huffman codes.
-- @param max_symbol The maximum symbol
-- @param max_bitlen The min huffman bit length of all codes
-- @return zero or positive for success, negative for failure.
-- @return The count of each huffman bit length.
-- @return A table to convert huffman codes to deflate codes.
-- @return The minimum huffman bit length.
local function GetHuffmanForDecode(huffman_bitlens, max_symbol, max_bitlen)
	local huffman_bitlen_counts = {}
	local min_bitlen = max_bitlen
	for symbol = 0, max_symbol do
		local bitlen = huffman_bitlens[symbol] or 0
		min_bitlen = (bitlen > 0 and bitlen < min_bitlen)
			and bitlen or min_bitlen
		huffman_bitlen_counts[bitlen] = (huffman_bitlen_counts[bitlen] or 0)+1
	end

	if huffman_bitlen_counts[0] == max_symbol+1 then -- No Codes
		return 0, huffman_bitlen_counts, {}, 0 -- Complete, but decode will fail
	end

	local left = 1
	for len = 1, max_bitlen do
		left = left * 2
		left = left - (huffman_bitlen_counts[len] or 0)
		if left < 0 then
			return left -- Over-subscribed, return negative
		end
	end

	-- Generate offsets info symbol table for each length for sorting
	local offsets = {}
	offsets[1] = 0
	for len = 1, max_bitlen-1 do
		offsets[len + 1] = offsets[len] + (huffman_bitlen_counts[len] or 0)
	end

	local huffman_symbols = {}
	for symbol = 0, max_symbol do
		local bitlen = huffman_bitlens[symbol] or 0
		if bitlen ~= 0 then
			local offset = offsets[bitlen]
			huffman_symbols[offset] = symbol
			offsets[bitlen] = offsets[bitlen] + 1
		end
	end

	-- Return zero for complete set, positive for incomplete set.
	return left, huffman_bitlen_counts, huffman_symbols, min_bitlen
end

-- Decode a fixed or dynamic huffman blocks, excluding last block identifier
-- and block type identifer.
-- @see puff.c:codes()
-- @param state decompression state that will be modified by this function.
--	@see CreateDecompressState
-- @param ... Read the source code
-- @return 0 on success, other value on failure.
local function DecodeUntilEndOfBlock(state, lcodes_huffman_bitlens
	, lcodes_huffman_symbols, lcodes_huffman_min_bitlen
	, dcodes_huffman_bitlens, dcodes_huffman_symbols
	, dcodes_huffman_min_bitlen)
	local buffer, buffer_size, ReadBits, Decode, ReaderBitlenLeft
		, result_buffer =
		state.buffer, state.buffer_size, state.ReadBits, state.Decode
		, state.ReaderBitlenLeft, state.result_buffer
	local dictionary = state.dictionary
	local dict_string_table
	local dict_strlen

	local buffer_end = 1
	if dictionary and not buffer[0] then
		-- If there is a dictionary, copy the last 258 bytes into
		-- the string_table to make the copy in the main loop quicker.
		-- This is done only once per decompression.
		dict_string_table = dictionary.string_table
		dict_strlen = dictionary.strlen
		buffer_end = -dict_strlen + 1
		for i=0, (-dict_strlen+1)<-257 and -257 or (-dict_strlen+1), -1 do
			buffer[i] = _byte_to_char[dict_string_table[dict_strlen+i]]
		end
	end

	repeat
		local symbol = Decode(lcodes_huffman_bitlens
			, lcodes_huffman_symbols, lcodes_huffman_min_bitlen)
		if symbol < 0 or symbol > 285 then
		-- invalid literal/length or distance code in fixed or dynamic block
			return -10
		elseif symbol < 256 then -- Literal
			buffer_size = buffer_size + 1
			buffer[buffer_size] = _byte_to_char[symbol]
		elseif symbol > 256 then -- Length code
			symbol = symbol - 256
			local bitlen = _literal_deflate_code_to_base_len[symbol]
			bitlen = (symbol >= 8)
				 and (bitlen
				 + ReadBits(_literal_deflate_code_to_extra_bitlen[symbol]))
					or bitlen
			symbol = Decode(dcodes_huffman_bitlens, dcodes_huffman_symbols
				, dcodes_huffman_min_bitlen)
			if symbol < 0 or symbol > 29 then
			-- invalid literal/length or distance code in fixed or dynamic block
				return -10
			end
			local dist = _dist_deflate_code_to_base_dist[symbol]
			dist = (dist > 4) and (dist
				+ ReadBits(_dist_deflate_code_to_extra_bitlen[symbol])) or dist

			local char_buffer_index = buffer_size-dist+1
			if char_buffer_index < buffer_end then
			-- distance is too far back in fixed or dynamic block
				return -11
			end
			if char_buffer_index >= -257 then
				for _=1, bitlen do
					buffer_size = buffer_size + 1
					buffer[buffer_size] = buffer[char_buffer_index]
					char_buffer_index = char_buffer_index + 1
				end
			else
				char_buffer_index = dict_strlen + char_buffer_index
				for _=1, bitlen do
					buffer_size = buffer_size + 1
					buffer[buffer_size] =
					_byte_to_char[dict_string_table[char_buffer_index]]
					char_buffer_index = char_buffer_index + 1
				end
			end
		end

		if ReaderBitlenLeft() < 0 then
			return 2 -- available inflate data did not terminate
		end

		if buffer_size >= 65536 then
			result_buffer[#result_buffer+1] =
				table_concat(buffer, "", 1, 32768)
			for i=32769, buffer_size do
				buffer[i-32768] = buffer[i]
			end
			buffer_size = buffer_size - 32768
			buffer[buffer_size+1] = nil
			-- NOTE: buffer[32769..end] and buffer[-257..0] are not cleared.
			-- This is why "buffer_size" variable is needed.
		end
	until symbol == 256

	state.buffer_size = buffer_size

	return 0
end

-- Decompress a store block
-- @param state decompression state that will be modified by this function.
-- @return 0 if succeeds, other value if fails.
local function DecompressStoreBlock(state)
	local buffer, buffer_size, ReadBits, ReadBytes, ReaderBitlenLeft
		, SkipToByteBoundary, result_buffer =
		state.buffer, state.buffer_size, state.ReadBits, state.ReadBytes
		, state.ReaderBitlenLeft, state.SkipToByteBoundary, state.result_buffer

	SkipToByteBoundary()
	local bytelen = ReadBits(16)
	if ReaderBitlenLeft() < 0 then
		return 2 -- available inflate data did not terminate
	end
	local bytelenComp = ReadBits(16)
	if ReaderBitlenLeft() < 0 then
		return 2 -- available inflate data did not terminate
	end

	if bytelen % 256 + bytelenComp % 256 ~= 255 then
		return -2 -- Not one's complement
	end
	if (bytelen-bytelen % 256)/256
		+ (bytelenComp-bytelenComp % 256)/256 ~= 255 then
		return -2 -- Not one's complement
	end

	-- Note that ReadBytes will skip to the next byte boundary first.
	buffer_size = ReadBytes(bytelen, buffer, buffer_size)
	if buffer_size < 0 then
		return 2 -- available inflate data did not terminate
	end

	-- memory clean up when there are enough bytes in the buffer.
	if buffer_size >= 65536 then
		result_buffer[#result_buffer+1] = table_concat(buffer, "", 1, 32768)
		for i=32769, buffer_size do
			buffer[i-32768] = buffer[i]
		end
		buffer_size = buffer_size - 32768
		buffer[buffer_size+1] = nil
	end
	state.buffer_size = buffer_size
	return 0
end

-- Decompress a fixed block
-- @param state decompression state that will be modified by this function.
-- @return 0 if succeeds other value if fails.
local function DecompressFixBlock(state)
	return DecodeUntilEndOfBlock(state
		, _fix_block_literal_huffman_bitlen_count
		, _fix_block_literal_huffman_to_deflate_code, 7
		, _fix_block_dist_huffman_bitlen_count
		, _fix_block_dist_huffman_to_deflate_code, 5)
end

-- Decompress a dynamic block
-- @param state decompression state that will be modified by this function.
-- @return 0 if success, other value if fails.
local function DecompressDynamicBlock(state)
	local ReadBits, Decode = state.ReadBits, state.Decode
	local nlen = ReadBits(5) + 257
	local ndist = ReadBits(5) + 1
	local ncode = ReadBits(4) + 4
	if nlen > 286 or ndist > 30 then
		-- dynamic block code description: too many length or distance codes
		return -3
	end

	local rle_codes_huffman_bitlens = {}

	for i = 1, ncode do
		rle_codes_huffman_bitlens[_rle_codes_huffman_bitlen_order[i]] =
			ReadBits(3)
	end

	local rle_codes_err, rle_codes_huffman_bitlen_counts,
		rle_codes_huffman_symbols, rle_codes_huffman_min_bitlen =
		GetHuffmanForDecode(rle_codes_huffman_bitlens, 18, 7)
	if rle_codes_err ~= 0 then -- Require complete code set here
		-- dynamic block code description: code lengths codes incomplete
		return -4
	end

	local lcodes_huffman_bitlens = {}
	local dcodes_huffman_bitlens = {}
	-- Read length/literal and distance code length tables
	local index = 0
	while index < nlen + ndist do
		local symbol -- Decoded value
		local bitlen -- Last length to repeat

		symbol = Decode(rle_codes_huffman_bitlen_counts
			, rle_codes_huffman_symbols, rle_codes_huffman_min_bitlen)

		if symbol < 0 then
			return symbol -- Invalid symbol
		elseif symbol < 16 then
			if index < nlen then
				lcodes_huffman_bitlens[index] = symbol
			else
				dcodes_huffman_bitlens[index-nlen] = symbol
			end
			index = index + 1
		else
			bitlen = 0
			if symbol == 16 then
				if index == 0 then
					-- dynamic block code description: repeat lengths
					-- with no first length
					return -5
				end
				if index-1 < nlen then
					bitlen = lcodes_huffman_bitlens[index-1]
				else
					bitlen = dcodes_huffman_bitlens[index-nlen-1]
				end
				symbol = 3 + ReadBits(2)
			elseif symbol == 17 then -- Repeat zero 3..10 times
				symbol = 3 + ReadBits(3)
			else -- == 18, repeat zero 11.138 times
				symbol = 11 + ReadBits(7)
			end
			if index + symbol > nlen + ndist then
				-- dynamic block code description:
				-- repeat more than specified lengths
				return -6
			end
			while symbol > 0 do -- Repeat last or zero symbol times
				symbol = symbol - 1
				if index < nlen then
					lcodes_huffman_bitlens[index] = bitlen
				else
					dcodes_huffman_bitlens[index-nlen] = bitlen
				end
				index = index + 1
			end
		end
	end

	if (lcodes_huffman_bitlens[256] or 0) == 0 then
		-- dynamic block code description: missing end-of-block code
		return -9
	end

	local lcodes_err, lcodes_huffman_bitlen_counts
		, lcodes_huffman_symbols, lcodes_huffman_min_bitlen =
		GetHuffmanForDecode(lcodes_huffman_bitlens, nlen-1, 15)
	--dynamic block code description: invalid literal/length code lengths,
	-- Incomplete code ok only for single length 1 code
	if (lcodes_err ~=0 and (lcodes_err < 0
		or nlen ~= (lcodes_huffman_bitlen_counts[0] or 0)
			+(lcodes_huffman_bitlen_counts[1] or 0))) then
		return -7
	end

	local dcodes_err, dcodes_huffman_bitlen_counts
		, dcodes_huffman_symbols, dcodes_huffman_min_bitlen =
		GetHuffmanForDecode(dcodes_huffman_bitlens, ndist-1, 15)
	-- dynamic block code description: invalid distance code lengths,
	-- Incomplete code ok only for single length 1 code
	if (dcodes_err ~=0 and (dcodes_err < 0
		or ndist ~= (dcodes_huffman_bitlen_counts[0] or 0)
			+ (dcodes_huffman_bitlen_counts[1] or 0))) then
		return -8
	end

	-- Build buffman table for literal/length codes
	return DecodeUntilEndOfBlock(state, lcodes_huffman_bitlen_counts
		, lcodes_huffman_symbols, lcodes_huffman_min_bitlen
		, dcodes_huffman_bitlen_counts, dcodes_huffman_symbols
		, dcodes_huffman_min_bitlen)
end

-- Decompress a deflate stream
-- @param state: a decompression state
-- @return the decompressed string if succeeds. nil if fails.
local function Inflate(state)
	local ReadBits = state.ReadBits

	local is_last_block
	while not is_last_block do
		is_last_block = (ReadBits(1) == 1)
		local block_type = ReadBits(2)
		local status
		if block_type == 0 then
			status = DecompressStoreBlock(state)
		elseif block_type == 1 then
			status = DecompressFixBlock(state)
		elseif block_type == 2 then
			status = DecompressDynamicBlock(state)
		else
			return nil, -1 -- invalid block type (type == 3)
		end
		if status ~= 0 then
			return nil, status
		end
	end

	state.result_buffer[#state.result_buffer+1] =
		table_concat(state.buffer, "", 1, state.buffer_size)
	local result = table_concat(state.result_buffer)
	return result
end

-- @see LibDeflate:DecompressDeflate(str)
-- @see LibDeflate:DecompressDeflateWithDict(str, dictionary)
local function DecompressDeflateInternal(str, dictionary)
	local state = CreateDecompressState(str, dictionary)
	local result, status = Inflate(state)
	if not result then
		return nil, status
	end

	local bitlen_left = state.ReaderBitlenLeft()
	local bytelen_left = (bitlen_left - bitlen_left % 8) / 8
	return result, bytelen_left
end

-- @see LibDeflate:DecompressZlib(str)
-- @see LibDeflate:DecompressZlibWithDict(str)
local function DecompressZlibInternal(str, dictionary)
	local state = CreateDecompressState(str, dictionary)
	local ReadBits = state.ReadBits

	local CMF = ReadBits(8)
	if state.ReaderBitlenLeft() < 0 then
		return nil, 2 -- available inflate data did not terminate
	end
	local CM = CMF % 16
	local CINFO = (CMF - CM) / 16
	if CM ~= 8 then
		return nil, -12 -- invalid compression method
	end
	if CINFO > 7 then
		return nil, -13 -- invalid window size
	end

	local FLG = ReadBits(8)
	if state.ReaderBitlenLeft() < 0 then
		return nil, 2 -- available inflate data did not terminate
	end
	if (CMF*256+FLG)%31 ~= 0 then
		return nil, -14 -- invalid header checksum
	end

	local FDIST = ((FLG-FLG%32)/32 % 2)
	local FLEVEL = ((FLG-FLG%64)/64 % 4) -- luacheck: ignore FLEVEL

	if FDIST == 1 then
		if not dictionary then
			return nil, -16 -- need dictonary, but dictionary is not provided.
		end
		local byte3 = ReadBits(8)
		local byte2 = ReadBits(8)
		local byte1 = ReadBits(8)
		local byte0 = ReadBits(8)
		local actual_adler32 = byte3*16777216+byte2*65536+byte1*256+byte0
		if state.ReaderBitlenLeft() < 0 then
			return nil, 2 -- available inflate data did not terminate
		end
		if not IsEqualAdler32(actual_adler32, dictionary.adler32) then
			return nil, -17 -- dictionary adler32 does not match
		end
	end
	local result, status = Inflate(state)
	if not result then
		return nil, status
	end
	state.SkipToByteBoundary()

	local adler_byte0 = ReadBits(8)
	local adler_byte1 = ReadBits(8)
	local adler_byte2 = ReadBits(8)
	local adler_byte3 = ReadBits(8)
	if state.ReaderBitlenLeft() < 0 then
		return nil, 2 -- available inflate data did not terminate
	end

	local adler32_expected = adler_byte0*16777216
		+ adler_byte1*65536 + adler_byte2*256 + adler_byte3
	local adler32_actual = LibDeflate:Adler32(result)
	if not IsEqualAdler32(adler32_expected, adler32_actual) then
		return nil, -15 -- Adler32 checksum does not match
	end

	local bitlen_left = state.ReaderBitlenLeft()
	local bytelen_left = (bitlen_left - bitlen_left % 8) / 8
	return result, bytelen_left
end

--- Decompress a raw deflate compressed data.
-- @param str [string] The data to be decompressed.
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressDeflate
function LibDeflate:DecompressDeflate(str)
	local arg_valid, arg_err = IsValidArguments(str)
	if not arg_valid then
		error(("Usage: LibDeflate:DecompressDeflate(str): "
			..arg_err), 2)
	end
	return DecompressDeflateInternal(str)
end

--- Decompress a raw deflate compressed data with a preset dictionary.
-- @param str [string] The data to be decompressed.
-- @param dictionary [table] The preset dictionary used by
-- LibDeflate:CompressDeflateWithDict when the compressed data is produced.
-- Decompression and compression must use the same dictionary.
-- Otherwise wrong decompressed data could be produced without generating any
-- error.
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressDeflateWithDict
function LibDeflate:DecompressDeflateWithDict(str, dictionary)
	local arg_valid, arg_err = IsValidArguments(str, true, dictionary)
	if not arg_valid then
		error(("Usage: LibDeflate:DecompressDeflateWithDict(str, dictionary): "
			..arg_err), 2)
	end
	return DecompressDeflateInternal(str, dictionary)
end

--- Decompress a zlib compressed data.
-- @param str [string] The data to be decompressed
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressZlib
function LibDeflate:DecompressZlib(str)
	local arg_valid, arg_err = IsValidArguments(str)
	if not arg_valid then
		error(("Usage: LibDeflate:DecompressZlib(str): "
			..arg_err), 2)
	end
	return DecompressZlibInternal(str)
end

--- Decompress a zlib compressed data with a preset dictionary.
-- @param str [string] The data to be decompressed
-- @param dictionary [table] The preset dictionary used by
-- LibDeflate:CompressDeflateWithDict when the compressed data is produced.
-- Decompression and compression must use the same dictionary.
-- Otherwise wrong decompressed data could be produced without generating any
-- error.
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressZlibWithDict
function LibDeflate:DecompressZlibWithDict(str, dictionary)
	local arg_valid, arg_err = IsValidArguments(str, true, dictionary)
	if not arg_valid then
		error(("Usage: LibDeflate:DecompressZlibWithDict(str, dictionary): "
			..arg_err), 2)
	end
	return DecompressZlibInternal(str, dictionary)
end

-- Calculate the huffman code of fixed block
do
	local _fix_block_literal_huffman_bitlen = {}
	for sym=0, 143 do
		_fix_block_literal_huffman_bitlen[sym] = 8
	end
	for sym=144, 255 do
		_fix_block_literal_huffman_bitlen[sym] = 9
	end
	for sym=256, 279 do
	    _fix_block_literal_huffman_bitlen[sym] = 7
	end
	for sym=280, 287 do
		_fix_block_literal_huffman_bitlen[sym] = 8
	end

	local _fix_block_dist_huffman_bitlen = {}
	for dist=0, 31 do
		_fix_block_dist_huffman_bitlen[dist] = 5
	end
	local status
	status, _fix_block_literal_huffman_bitlen_count
		, _fix_block_literal_huffman_to_deflate_code =
		GetHuffmanForDecode(_fix_block_literal_huffman_bitlen, 287, 9)
	assert(status == 0)
	status, _fix_block_dist_huffman_bitlen_count,
		_fix_block_dist_huffman_to_deflate_code =
		GetHuffmanForDecode(_fix_block_dist_huffman_bitlen, 31, 5)
	assert(status == 0)
end

-- For test. Don't use the functions in this table for real application.
-- Stuffs in this table is subject to change.
LibDeflate.internals = {
	IsValidDictionary = IsValidDictionary,
	IsEqualAdler32 = IsEqualAdler32,
}

return LibDeflate
