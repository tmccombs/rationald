module bytecurry.rational;

import std.exception : assumeWontThrow;
import std.format;
import std.math : abs;
import std.numeric : gcd;
import std.traits;

/**
 * A struct to accurately represent rational numbers (including fractions).
 */
struct Rational(T) if (isIntegral!T) {
private:
    /// Numerator
    T num;
    /// Denominator
    T den;

public:
    /**
     * Create a rational from a numerator and denominator
     */
    this(N: T, D: T)(N n, D d) pure nothrow {
        num = n;
        den = d;
        normalize();
    }

    ///
    @safe unittest {
        auto r = Rational(cast(T) 1, cast(T) 2);
        assert(r.numerator == 1);
        assert(r.denominator == 2);
    }

    ///
    @safe unittest {
        auto r = Rational(cast(T) 10, cast(T) 25);
        assert(r.numerator == 2);
        assert(r.denominator == 5);
    }



    /**
     * Create a rational from an integer.
     */
    this(I: T)(I n) pure nothrow {
        num = n;
        den = 1;
    }

    this(U: T)(const Rational!U other) pure nothrow {
        opAssign(other);
    }

    /**
     * Return the numerator of the fraction.
     */
    @property T numerator() pure nothrow const {
        return num;
    }
    /**
     * Return the denominator of the fraction.
     */
    @property T denominator() pure nothrow const {
        return den;
    }

    /**
     * Return if the rational is infinite. i.e. if the denominator is zero and the numerator
     * is non-zero
     */
    @property bool isInfinity() pure nothrow const {
        return den == 0 && num != 0;
    }

    ///
    @safe unittest {
        assert(Rational(cast(T) 1, cast(T) 0).isInfinity);
        assert(!Rational(cast(T) 0, cast(T) 0).isInfinity);
        assert(!Rational(cast(T) 0, cast(T) 1).isInfinity);
    }

    /**
     * Return if the rational is finite. i.e. if the denominator is non-zero.
     */
    @property bool isFinite() pure nothrow const {
        return den != 0;
    }
    ///
    @safe unittest {
        assert(!Rational(cast(T) 1, cast(T) 0).isFinite);
        assert(!Rational(cast(T) 0, cast(T) 0).isFinite);
        assert(Rational(cast(T) 0, cast(T)1).isFinite);
    }

    /**
     * Return whether or not the rational is indeterminate (not a number), i.e. both the numerator and
     * denominator are zero.
     */
    @property bool isNaN() pure nothrow const {
        return den == 0 && num == 0;
    }
    ///
    @safe unittest {
        assert(!Rational(cast(T) 1, cast(T) 0).isNaN);
        assert(Rational(cast(T) 0, cast(T) 0).isNaN);
        assert(!Rational(cast(T) 0, cast(T)1).isNaN);
    }

    // Assignment Operators:

    ///
    Rational opAssign(U: T)(Rational!U other) pure nothrow @nogc {
        num = other.num;
        den = other.den;
        return this;
    }

    ///
    Rational opAssign(I: T)(I other) pure nothrow @nogc {
        num = other;
        den = 1;
        return this;
    }

    // Comparison Operators:

    ///
    bool opEquals(U)(auto ref const Rational!U other) pure nothrow const {
        return num == other.num && den == other.den;
    }

    /// ditto
    bool opEquals(I)(in I other) pure nothrow const if (isIntegral!I) {
        return num == other && den == 1;
    }

    ///
    @safe unittest {
        assert(Rational(cast(T) 1, cast(T) 2) == Rational(cast(T) 2, cast(T) 4));
        assert(Rational(cast(T) 5, cast(T) 1) == 5);
    }


    ///
    int opCmp(U)(auto ref const Rational!U other) pure nothrow const {
        // TODO: fix overflow
        auto left = num * other.den;
        auto right = other.num * den;
        if (left < right) {
            return -1;
        } else if (left > right) {
            return 1;
        } else {
            return 0;
        }
    }

    /// ditto
    int opCmp(I)(in I other) pure nothrow const @nogc if (isIntegral!I) {
        //TODO: fix overflow
        auto right = other * den;
        if (num < right) {
            return -1;
        } else if (num > right) {
            return 1;
        } else {
            return 0;
        }
    }

    ///
    @safe unittest {
        assert(Rational(cast(T) 2, cast(T) 3) > Rational(cast(T) 1, cast(T) 2));
        assert(Rational(cast(T) 4, cast(T) 5) < Rational(cast(T) 3, cast(T) 2));
        assert(Rational(cast(T) 3, cast(T) 2) >= Rational(cast(T) 3, cast(T) 2));
        assert(Rational(cast(T) 3, cast(T) 2) > 1);
        assert(Rational(cast(T) 1, cast(T) 2) < 1);
        assert(Rational(cast(T) 4, cast(T) 4) >= 1);

        assert(Rational(cast(T) 2, cast(T) 3) > Rational!int(1, 2));
    }

    // Unary Operators:

    ///
    Rational opUnary(string op)() const pure nothrow if (op == "+") {
        return this;
    }

    static if (isSigned!T) {
        ///
        Rational opUnary(string op)() const pure nothrow if (op == "-") {
            return Rational(-num, den);
        }
        ///
        @safe unittest {
            assert(-Rational(cast(T) 1, cast(T) 2) == Rational( cast(T) -1, cast(T) 2));
            assert(-Rational(cast(T) -1, cast(T) 2) == Rational(cast(T) 1, cast(T) 2));
        }
    }


    /// Binary operators
    Rational!(CommonType!(T,U)) opBinary(string op, U)(Rational!U other) const pure nothrow {
        alias R = typeof(return);
        auto ret = R(num, den);
        return ret.opOpAssign!(op)(other);
    }

    /// ditto
    Rational!(CommonType!(T,U)) opBinary(string op, U)(U other) const pure nothrow if (isIntegral!U) {
        alias R = typeof(return);
        auto ret = R(num, den);
        return ret.opOpAssign!(op)(other);
    }

    /// ditto
    F opBinary(string op, F)(F other) const pure nothrow
        if (op == "^^" && isFloatingPoint!F)
    {
        return (cast(F) this) ^^ other;
    }

    // int + rational, and int * rational
    /// ditto
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if ((op == "+" || op == "*") && isIntegral!U)
    {
        return opBinary!(op)(other);
    }

    /// ditto
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if (op == "-" && isIntegral!U)
    {
        return typeof(return)(other * den - num, den);
    }

    /// ditto
    Rational!(CommonType!(T,U)) opBinaryRight(string op, U)(U other) const pure nothrow
    if (op == "/" && isIntegral!U)
    {
        return typeof(return)(other * den, num);
    }

    ///
    @safe unittest {
        assert(Rational(cast(T) 1, cast(T) 4) ^^ 0.5 == 0.5);
        assert(1 + Rational(cast(T) 3, cast(T) 2) == Rational!int(5,2));
        assert(2 * Rational(cast(T) 1, cast(T) 2) == Rational!int(1,1));
        assert(2 - Rational(cast(T) 1, cast(T) 2) == Rational!int(3,2));
        assert(3 / Rational(cast(T) 2, cast(T) 3) == Rational!int(9,2));

        assert(Rational(cast(T) 3, cast(T) 2) + 1 == Rational!int(5,2));
        assert(Rational(cast(T) 1, cast(T) 2) * 2 == Rational!int(1,1));
        assert(Rational(cast(T) 1, cast(T) 2) - 2 == Rational!int(-3,2));
        assert(Rational(cast(T) 2, cast(T) 3) / 3 == Rational!int(2,9));

        assert(Rational(cast(T) 3, cast(T) 2) + Rational(cast(T) 2, cast(T) 3) == Rational!int(13, 6));
        assert(Rational(cast(T) 3, cast(T) 2) - Rational(cast(T) 2, cast(T) 3) == Rational!int(5,6));
        assert(Rational(cast(T) 3, cast(T) 2) * Rational(cast(T) 2, cast(T) 5) == Rational!int(3, 5));
        assert(Rational(cast(T) 3, cast(T) 2) / Rational(cast(T) 5, cast(T) 11) == Rational!int(33, 10));

        assert(Rational(cast(T) 2, cast(T) 3) ^^ 2 == Rational!int(4, 9));
    }

    // Op-Assign Operators:

    ///
    ref Rational opOpAssign(string op, U: T)(U other) pure nothrow
    if ((op == "+" || op == "-" || op == "*" || op == "/") && is(U: T))
    {
        static if (op == "+" || op == "-") {
            add!op(other);
        } else static if (op == "*") {
            multiply(other);
        } else static if (op == "/") {
            multiply(1, other);
        }
        return this;
    }

    ///
    ref Rational opOpAssign(string op, U: T)(Rational!U other) pure nothrow
    if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        static if (op == "+" || op == "-") {
            add!op(other.num, other.den);
        } else static if (op == "*") {
            multiply(other.num, other.den);
        } else static if (op == "/") {
            multiply(other.den, other.num);
        }
        return this;
    }

    ///
    ref Rational opOpAssign(string op, U)(U exp) pure nothrow if (op == "^^" && isIntegral!U) {
        num ^^= exp;
        den ^^= exp;
        normalize();
        return this;
    }

    // Cast Operators:

    /// cast to floating point type
    F opCast(F)() pure nothrow const if (isFloatingPoint!F) {
        return (cast(F) num) / (cast(F) den);
    }

    /// cast to integer type
    I opCast(I)() pure nothrow const if (isIntegral!I) {
        return cast(I) (num / den);
    }

    /**
     * Write the rational to a sink. It supports the same formatting option as integers
     * and outputs the numerator and denominator using those options.
     *
     * If the denominator is on, the / and denominator aren't output.
     * At some point I might make this more sophisticated.
     */
    void toString(Char)(scope void delegate(const(Char)[]) sink, FormatSpec!Char fmt) const {
        if (fmt.spec == '/') {
            if (fmt.flPlus && num > 0) {
                // special formatting for positive numbers
                if (fmt.flPlus) {
                    sink("+");
                }
            }
            auto intSpec = FormatSpec!Char("%d");
            formatValue(sink, num, intSpec);
            if ( fmt.flHash || den != 1) {
                if (fmt.flSpace) {
                    sink(" / ");
                } else {
                    sink("/");
                }
                formatValue(sink, den, intSpec);
            }
        } else {
            formatValue(sink, num, fmt);
            if (den != 1) {
                sink("/");
                formatValue(sink, den, fmt);
            }
        }
     }

    /// convert to string
    string toString() const {
        import std.array : appender;
        auto buf = appender!string();
        auto spec = singleSpec("%s");
        toString((const(char)[] c) { buf.put(c); }, spec);
        //formatValue(buf, this, spec);
        return buf.data;
    }
    ///
    unittest {
        assert(Rational(cast(T) 1, cast(T) 2).toString == "1/2");
        assert(Rational(cast(T) 5).toString == "5");

        assert(format("%/", rational(1,2)) == "1/2");
        assert(format("%/", rational(2,1)) == "2");
        assert(format("%#/", rational(2,1)) == "2/1");
        assert(format("%+/", rational(1,2)) == "+1/2");
        assert(format("%+#/", rational(3,1)) == "+3/1");
        assert(format("% /", rational(1,2)) == "1 / 2");
        assert(format("%# /", rational(1,1)) == "1 / 1");
        assert(format("%+ /", rational(1,2)) == "+1 / 2");
    }


private:
    void multiply(T otherNum, T otherDen = 1) pure nothrow {
        num *= otherNum;
        den *= otherDen;
        normalize();
    }

    void add(string op = "+")(T otherNum, T otherDen = 1) pure nothrow {
        num = cast(T) mixin(q{num * otherDen} ~ op ~ q{otherNum * den});
        den = cast(T) (den * otherDen);
        normalize();
    }

    void normalize() pure nothrow {
        if (den < 0) {
            num = - num;
            den = - den;
        }
        T divisor = assumeWontThrow(gcd(num.abs, den));
        if (divisor > 1) {
            num /= divisor;
            den /= divisor;
        }
    }

    invariant {
        assert(den >= 0);
        assert(gcd(num.abs, den) == 1 || (num == 0 && den == 0));
    }

}

@safe unittest {
    // just test insantiate Rational for a bunch of types
    auto r1 = Rational!byte();
    auto r2 = Rational!ubyte();
    auto r3 = Rational!short();
    auto r4 = Rational!ushort();
    auto r5 = Rational!int();
    auto r6 = Rational!uint();
    auto r7 = Rational!long();
    auto r8 = Rational!ulong();
}

/**
Create a rational object, with $(D n) as the numerator and $(D d) as the denominator.
 */
Rational!(CommonType!(A,B)) rational(A,B)(A n, B d) if (isIntegral!A && isIntegral!B) {
    alias R = typeof(return);
    return R(n, d);
}

/// ditto
Rational!T rational(T)(T n) if (isIntegral!T) {
    return Rational!T(n, 1);
}

///
unittest {
    auto a = rational(6,10);
    assert(a.numerator == 3);
    assert(a.denominator == 5);

    assert(a == rational(3,5));
    assert(a * 2 == rational(6,5));
    assert(a / 2 == rational(3,10));

    assert(a + rational(1,10) == rational(7,10));

}

import std.range : isInputRange, ElementType;

/**
 * Parse a fraction from an input source.
 * The rational is in the from "%d / %d".
 *
 * Parameters: `source` is a range of characters that is parsed as a rational. `source` is modified
 * to contain the remainder of the source.
 */
Rational!T parseFraction(T = int, Source)(ref Source source)
if (isInputRange!Source && isSomeChar!(ElementType!Source) && isIntegral!T) {
    T num, den = 1;
    uint read = formattedRead(source, "%d / %d", &num, &den);
    //TODO: throw exception if we didn't read at least one number
    return Rational!T(num, den);
}

///
unittest {
    import std.range;
    string s = "1/2 abcef";
    assert(parseFraction!int(s) == rational(1,2));
    assert(s == " abcef");
    s = "4 / 3";
    assert(parseFraction!int(s) == rational(4, 3));
}
