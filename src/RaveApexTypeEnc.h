// ==============================================================================
// RAVE APEX — PURE-C OBJC TYPE-ENCODING CLASSIFIER
// ==============================================================================
// Decides, WITHOUT the ObjC runtime, whether a completion block is safely
// callable as void(^)(BOOL) and whether a method has a forwardable
// completion-hook shape. Pure C so it is unit-testable natively off-device
// (see tests/apex_typeenc_test.c) and carries no NSMethodSignature dependency.
#ifndef RAVE_APEX_TYPEENC_H
#define RAVE_APEX_TYPEENC_H

// Advance past exactly one ObjC type encoding (not its trailing offset digits).
static const char *apex_skip_one_type(const char *p) {
    if (!p || !*p) return p;
    switch (*p) {
        case '@': // object, block (@?) or typed object (@"Name")
            p++;
            if (*p == '?') { p++; }
            else if (*p == '"') { p++; while (*p && *p != '"') p++; if (*p == '"') p++; }
            break;
        case '^': // pointer-to-type
            p++;
            p = apex_skip_one_type(p);
            break;
        case '{': case '(': { // struct / union (nested)
            char open = *p, close = (open == '{') ? '}' : ')';
            int depth = 0;
            do { if (*p == open) depth++; else if (*p == close) depth--; p++; } while (*p && depth > 0);
            break;
        }
        case '[': // array
            p++;
            while (*p && *p != ']') p++;
            if (*p == ']') p++;
            break;
        case 'r': case 'n': case 'N': case 'o': case 'O': case 'R': case 'V': // qualifier, then type
            p++;
            p = apex_skip_one_type(p);
            break;
        default:
            p++;
            break;
    }
    return p;
}

// Tokenise a method/block type encoding into base-type chars (return type first,
// then each argument). Objects and blocks both reduce to '@'. Returns token count.
static int apex_parse_types(const char *enc, char *out, int maxOut) {
    int count = 0;
    const char *p = enc;
    if (!enc || !out) return 0;
    while (*p && count < maxOut) {
        const char *q = p;
        while (*q == 'r' || *q == 'n' || *q == 'N' || *q == 'o' ||
               *q == 'O' || *q == 'R' || *q == 'V') q++;   // skip qualifiers for base
        out[count++] = *q;                                  // base type char
        p = apex_skip_one_type(p);                          // advance past whole type
        while (*p >= '0' && *p <= '9') p++;                 // skip stack offset
    }
    return count;
}

// A block signature describes void(^)(BOOL) iff: [ret 'v', block-self '@', bool].
static int apex_sig_is_void_bool(const char *sig) {
    char t[16];
    int n = apex_parse_types(sig, t, 16);
    return (n == 3 && t[0] == 'v' && (t[2] == 'B' || t[2] == 'c'));
}

// A hookable completion method returns void and ends in a block arg. Sets:
//   *shape = 1 for (self,_cmd,completion),
//   *shape = 2 for (self,_cmd,object,completion),
//   *shape = 3 for (self,_cmd,object,object,completion).
// Returns 1 if forwardable, 0 otherwise (unknown/primitive leading arg, etc.).
static int apex_completion_shape(const char *te, int *shape) {
    char t[24];
    int n = apex_parse_types(te, t, 24);
    if (n < 4 || t[0] != 'v') return 0;     // must return void
    if (t[n - 1] != '@') return 0;          // last arg must be the block (@?)
    if (n == 4) { if (shape) *shape = 1; return 1; }                 // ret,self,cmd,block
    if (n == 5) { if (t[3] != '@') return 0; if (shape) *shape = 2; return 1; } // +object
    if (n == 6) { if (t[3] != '@' || t[4] != '@') return 0; if (shape) *shape = 3; return 1; } // +2 objects
    return 0;
}

// Case-insensitive: does `name` contain any needle? (needles must be lowercase)
static int apex_name_has(const char *name, const char *const *needles, int n) {
    char lower[256];
    int i = 0;
    if (!name) return 0;
    for (; name[i] && i < 255; i++) {
        char ch = name[i];
        if (ch >= 'A' && ch <= 'Z') ch += 32;
        lower[i] = ch;
    }
    lower[i] = '\0';
    for (int k = 0; k < n; k++) {
        const char *ndl = needles[k];
        if (!ndl) continue;
        // tiny substring search (avoids <string.h> dependency in pure-C tests)
        for (const char *h = lower; *h; h++) {
            const char *a = h, *b = ndl;
            while (*a && *b && *a == *b) { a++; b++; }
            if (!*b) return 1;
        }
    }
    return 0;
}

#endif // RAVE_APEX_TYPEENC_H
