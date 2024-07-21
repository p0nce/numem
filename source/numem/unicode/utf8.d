module numem.unicode.utf8;
import numem.unicode;
import numem.mem.string;
import numem.mem.vector;

private {
    enum utf8_datamask(uint offset) = 0xFF >> offset;
    enum utf8_leadmask(uint offset) = ~utf8_datamask!offset;

    // Highest ascii value in UTF8
    enum utf8_ascii = 0x7F;

    struct utf8_t {
        ubyte lead;
    }

    // Lookup table containing the correct byte patterns and codepoints for each
    // utf8 codepoint size.
    const ubyte[4] utf8_leadmasks = [
        0b00000000,  // Lead byte (1 byte)
        0b11000000,  // Lead byte (2 bytes)
        0b11100000,  // Lead byte (3 bytes)
        0b11110000,  // Lead byte (4 bytes)
    ];

    // UTF-8 Well-Formed Byte Sequence Table
    // A translation of Table 3-7 in the unicode conformance documents.
    const ubyte[2][4][9] utf8_wfbseqtable = [
        [[0x00, 0x7F], [0x00, 0xFF], [0x00, 0xFF], [0x00, 0xFF]],
        [[0xC2, 0xDF], [0x80, 0xBF], [0x00, 0xFF], [0x00, 0xFF]],
        [[0xE0, 0xE0], [0xA0, 0xBF], [0x80, 0xBF], [0x00, 0xFF]],
        [[0xE1, 0xEC], [0x80, 0xBF], [0x80, 0xBF], [0x00, 0xFF]],
        [[0xED, 0xED], [0x80, 0x9F], [0x80, 0xBF], [0x00, 0xFF]],
        [[0xEE, 0xEF], [0x80, 0xBF], [0x80, 0xBF], [0x00, 0xFF]],
        [[0xF0, 0xF0], [0x90, 0xBF], [0x80, 0xBF], [0x80, 0xBF]],
        [[0xF1, 0xF3], [0x80, 0xBF], [0x80, 0xBF], [0x80, 0xBF]],
        [[0xF4, 0xF4], [0x80, 0x8F], [0x80, 0xBF], [0x80, 0xBF]],
    ];
}

/**
    Validates a utf-8 character sequence.
*/
bool validate(const(char)[4] seq) {
    
    // Validate and get length.
    size_t len = getLength(seq[0]);
    if (!len) return false;

    switch(len) {
        default: return false;

        // 
        case 1:
            bool condition = 
                (seq[0] >= utf8_wfbseqtable[0][0][0] && seq[0] <= utf8_wfbseqtable[0][0][1]);
            if (condition) return true;
            return false;

        case 2:
            bool condition = 
                (seq[0] >= utf8_wfbseqtable[1][0][0] && seq[0] <= utf8_wfbseqtable[1][0][1]) && 
                (seq[1] >= utf8_wfbseqtable[1][1][0] && seq[1] <= utf8_wfbseqtable[1][1][1]);
            if (condition) return true;
            return false;

        case 3:
            static foreach(tableIdx; 2..6) {
                
                // Codegen scope shenanigans
                {
                    bool condition = 
                        (seq[0] >= utf8_wfbseqtable[tableIdx][0][0] && seq[0] <= utf8_wfbseqtable[tableIdx][0][1]) && 
                        (seq[1] >= utf8_wfbseqtable[tableIdx][1][0] && seq[1] <= utf8_wfbseqtable[tableIdx][1][1]) && 
                        (seq[2] >= utf8_wfbseqtable[tableIdx][2][0] && seq[2] <= utf8_wfbseqtable[tableIdx][2][1]);
                    if (condition) return true;
                }
            }
            return false;

        case 4:
            static foreach(tableIdx; 6..9) {
                
                // Codegen scope shenanigans
                {
                    bool condition = 
                        (seq[0] >= utf8_wfbseqtable[tableIdx][0][0] && seq[0] <= utf8_wfbseqtable[tableIdx][0][1]) && 
                        (seq[1] >= utf8_wfbseqtable[tableIdx][1][0] && seq[1] <= utf8_wfbseqtable[tableIdx][1][1]) && 
                        (seq[2] >= utf8_wfbseqtable[tableIdx][2][0] && seq[2] <= utf8_wfbseqtable[tableIdx][2][1]) && 
                        (seq[3] >= utf8_wfbseqtable[tableIdx][3][0] && seq[3] <= utf8_wfbseqtable[tableIdx][3][1]);
                    if (condition) return true;
                }
            }
            return false;
    }
}

@("UTF-8 byte seq validation")
unittest {
    
    assert( validate([0x24, 0x00, 0x00, 0x00]));
    assert( validate([0xF4, 0x80, 0x83, 0x92]));

    assert(!validate([0xC0, 0xAF, 0x00, 0x00]));
    assert(!validate([0xE0, 0x9F, 0x80, 0x00]));
}

/**
    Returns whether the specified string is a valid UTF-8 string
*/
bool validate(nstring str) {
    size_t i = 0;
    while(i < str.size) {
        char[4] txt;

        // Validate length
        size_t clen = getLength(str[i]);
        if (clen >= i+str.size()) return false;
        if (clen == 0) return false;
        
        // Validate sequence
        txt[0..clen] = str[i..i+clen];
        if (!validate(txt)) return false;

        // iteration
        i += clen;
    }

    return true;
}

@("UTF-8 string validation")
unittest {
    
    assert( validate(nstring("Hello, world!")));
    assert( validate(nstring("こんにちは世界！")));

    // Invalid sequence test
    assert(!validate(nstring([0xC1, 0xBF, 0xCC])));
    assert(!validate(nstring([0xF4, 0x9F, 0xBF, 0xBF])));
    assert(!validate(nstring([0xF4, 0x80]))); // Sequence is cut off
}

/**
    Gets the expected byte-size of the specified character

    Returns 0 on malformed leading byte
*/
size_t getLength(char c) {
    static foreach_reverse(i; 0..utf8_leadmasks.length) {
        if ((c & utf8_leadmask!(i+1)) == utf8_leadmasks[i]) {
            return i+1;
        }
    }

    // Malformed leading byte
    return 0;
}

@("UTF-8 char len")
unittest {
    assert('a'.getLength == 1);
    assert((0b11110000).getLength == 4);
    assert((0xC0).getLength() == 2);
    assert((0b10010101).getLength() == 0); // Malformed leading byte
}


/**
    Decodes a UTF-8 character
*/
codepoint decode(const(char)[4] utf, ref size_t read) {
    codepoint code = 0x00;
    size_t needed = 0;
    
    ubyte lower = 0x80;
    ubyte upper = 0xBF;

    size_t len = getLength(utf[0]);
    if (len == 1) {

        // ASCII
        return utf[0];
    } else if (len == 2) {

        // 2 byte code
        needed = 1;
        code = utf[0] & 0x1F;
    } else if (len == 3) {

        // 3 byte code
        if (utf[0] == 0xA0) lower = 0xA0;
        if (utf[0] == 0x9F) upper = 0x9F;
        needed = 2;
        code = utf[0] & 0xF;
    } else if (len == 4) {

        // 4 byte code
        if (utf[0] == 0xF0) lower = 0x90;
        if (utf[0] == 0xF4) upper = 0x8F;
        needed = 3;
        code = utf[0] & 0x7;
    } else {

        // Replacement character \uFFFD
        return 0xFFFD;
    }

    // Return how many bytes are read
    read = needed+1;

    // Decoding
    foreach(i; 1..needed+1) {

        // Invalid character!
        if (utf[i] < lower || utf[i] > upper) {
            read = i;
            return 0xFFFD;
        }

        code = (code << 6) | (utf[i] & 0x3F);
    }
    return code;
}


/**
    Decodes the specified UTF-8 character

    Returns 0xFFFD if character is a malformed UTF-8 sequence
*/
codepoint decode(const(char)[4] utf) {
    size_t throwaway;
    return decode(utf, throwaway);
}

@("UTF-8 decode char")
unittest {
    assert(decode(['a', 0x00, 0x00, 0x00]) == cast(uint)'a');
    assert(decode([0xEB, 0x9D, 0xB7, 0x00]) == 0xB777);
    assert(decode([0xFF, 0xFF, 0xFF, 0xFF]) == 0xFFFD);
}

/**
    Decodes a string to a vector of codepoints.
    Invalid codes will be replaced with 0xFFFD
*/
UnicodeSequence decode(nstring str) {
    UnicodeSequence code;

    size_t i = 0;
    while(i < str.size()) {
        char[4] txt;

        // Validate length, add FFFD if invalid.
        size_t clen = str[i].getLength();
        if (clen >= i+str.size() || clen == 0) {
            code ~= 0xFFFD;
            i++;
        }

        txt[0..clen] = str[i..i+clen];
        code ~= txt.decode(clen);
        i += clen;
    }

    return code;
}

@("UTF-8 string decode")
unittest {
    import std.stdio : writeln;
    assert(decode(nstring("Hello, world!"))[0..$] == [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33]);
    assert(decode(nstring("こんにちは世界！"))[0..$] == [0x3053, 0x3093, 0x306b, 0x3061, 0x306f, 0x4e16, 0x754c, 0xff01]);

    assert(decode(nstring("こ\xF0\xA4\xADにちは世界！"))[0..$] == [0x3053, 0xFFFD, 0x306b, 0x3061, 0x306f, 0x4e16, 0x754c, 0xff01]);
}

/**
    Encodes a series of unicode sequences to UTF-8
*/
nstring encode(UnicodeSlice sequence) {
    nstring out_;
    
    size_t i = 0;
    while(i < sequence.length) {
        ptrdiff_t count = 0;
        ptrdiff_t offset = 0;
        if (sequence[i] <= utf8_ascii) {

            // Single-byte ascii
            out_ ~= cast(char)sequence[i++];
            continue;
        } else if (sequence[i] >= 0x0080 && sequence[i] <= 0x07FF) { 

            // 2 byte
            count = 1;
            offset = 0xC0;
        } else if (sequence[i] >= 0x0800 && sequence[i] <= 0xFFFF) { 

            // 2 byte
            count = 2;
            offset = 0xE0;
        } else if (sequence[i] >= 0x10000 && sequence[i] <= 0x10FFFF) { 

            // 2 byte
            count = 3;
            offset = 0xF0;
        }


        char[4] bytes;
        bytes[0] = cast(ubyte)((sequence[i] >> (6 * count)) + offset);
        size_t ix = 1;
        while (count > 0) {
            size_t temp = sequence[i] >> (6 * (count - 1));
            bytes[ix++] = 0x80 | (temp & 0x3F);
            count--;
        }

        out_ ~= bytes[0..ix];
        i++;
    }

    return out_;
}

/**
    Encodes a series of unicode sequences to UTF-8
*/
nstring encode(UnicodeSequence sequence) {
    return encode(sequence[0..$]);
}

@("UTF-8 encode")
unittest {
    assert(encode([0x3053, 0x3093, 0x306b, 0x3061, 0x306f, 0x4e16, 0x754c, 0xff01]) == "こんにちは世界！");
    assert(encode([0x3053, 0xFFFD, 0x306b, 0x3061, 0x306f, 0x4e16, 0x754c, 0xff01]) == "こ\uFFFDにちは世界！");
}