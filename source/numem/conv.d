/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

/**
    Utilities for converting between some basic types
*/
module numem.conv;
import numem.all;
import core.stdc.stdlib;
import core.stdc.stdio : snprintf;
import std.traits;
import numem.core.exception;

@nogc:

/**
    Convert nstring to signed integer
*/
T toInt(T)(nstring str) nothrow if (isSigned!T && isIntegral!T) {
    return cast(T)atol(str.toCString());
}

/**
    Convert string slice to signed integer
*/
T toInt(T)(string str) nothrow if (isSigned!T && isIntegral!T) {
    return cast(T)strtol(str.ptr, str.ptr+str.length);
}

/**
    Convert nstring to unsigned integer
*/
T toInt(T)(nstring str, int base) nothrow if (isUnsigned!T && isIntegral!T) {
    const(char)* ptr = str.toCString();
    return cast(T)strtoull(ptr, null, base);
}

/**
    Convert string slice to unsigned integer
*/
T toInt(T)(string str, int base) nothrow if (isUnsigned!T && isIntegral!T) {
    enum tSize = T.sizeof*2;
    size_t toCopy = 
        str.length < tSize ?
        str.length :
        tSize;

    nstring tmp;
    tmp ~= str[0..toCopy];
    return cast(T)strtoull(tmp.toCString(), null, base);
}

/**
    Convert nstring to float
*/
T toFloat(T)(nstring str) nothrow if (isFloatingPoint!T) {
    return cast(T)atof(str.toCString());
}

/**
    Convert string slice to float
*/
T toFloat(T)(string str) nothrow if (isFloatingPoint!T)  {
    return cast(T)strtof(str.ptr, str.ptr+str.length);
}

/**
    Converts an integer type into a hex string
*/
nstring toHexString(T, bool upper=false)(T num, bool pad=false) if (isIntegral!T && isUnsigned!T) {
    const string hexStr = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    nstring str;

    ptrdiff_t i = T.sizeof*2;
    while(num > 0) {
        str ~= hexStr[num % 16];
        i--;
        num /= 16;
    }

    str.reverse();

    // Add padding
    if (pad) {
        nstring padding;
        while(i-- > 0)
            padding ~= '0';

        padding ~= str;
        return padding;
    }

    // No padding
    return str;
}

@("conv: toHexString")
unittest {
    nstring hexstr = 0xDEADBEEF.toHexString();
    assert(hexstr == "deadbeef", hexstr[]);
}

/**
    Convert signed integers to nstring
*/
nstring toString(T)(T item) if (isSigned!T && isIntegral!T && !is(T == enum)) {
    nstring str;

    size_t count = snprintf(null, 0, "%lli", cast(ulong)item);
    str.resize(count);

    char* istr = cast(char*)str.toCString();
    snprintf(istr, count+1, "%lli", cast(ulong)item);
    return str;
}

/**
    Convert unsigned integers to nstring
*/
nstring toString(T)(T item) if (isUnsigned!T && isIntegral!T && !is(T == enum)) {
    nstring str;

    size_t count = snprintf(null, 0, "%llu", cast(ulong)item);
    str.resize(count);

    char* istr = cast(char*)str.toCString();
    snprintf(istr, count+1, "%llu", cast(ulong)item);
    return str;
}

/**
    Convert floating point numbers to nstring
*/
nstring toString(T)(T item) if (isFloatingPoint!T) {
    nstring str;

    size_t count = snprintf(null, 0, "%lf", item);
    str.resize(count);

    char* istr = cast(char*)str.toCString();
    snprintf(istr, count+1, "%lf", item);
    return str;
}

/**
    Convert bool to nstring
*/
nstring toString(T)(T item) if (is(T == bool)) {
    return item ? nstring("true") : nstring("false");
}

/**
    Convert enum to nstring
*/
nstring toString(T)(T item) if (is(T == enum)) {
    static foreach(member; EnumMembers!T) {
        if (item == member) return nstring(member.stringof);
    }
    throw nogc_new!NuException(nstring("Index out of range"));
}

/**
    Allows types to implement a toNString function
*/
nstring toString(T)(T item) if (__traits(hasMember, T, "toNString")) {
    return item.toNString();
}

@("toString")
unittest {
    import core.stdc.stdio : printf;
    assert(32u.toString() == "32");
    assert(12.0f.toString() == "12.000000");
    assert(true.toString() == "true");
    assert(false.toString() == "false");
    assert((-10_000).toString() == "-10000");
}

@("toString w/ enum")
unittest {
    enum TestEnum {
        a,
        b,
        longerName
    }
    
    assert(TestEnum.a.toString() == "a");
    assert(TestEnum.b.toString() == "b");
    assert(TestEnum.longerName.toString() == "longerName");
}