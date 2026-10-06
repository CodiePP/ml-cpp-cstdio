
// OCaml includes
extern "C" {
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/custom.h>
// #include <caml/callback.h>
#include <caml/fail.h>
} //extern C

// C++ includes
#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <new>

struct _cpp_cstdio_file {
    FILE *_file {nullptr};
};

#define CPP_CSTDIO_FILE(v) (*((_cpp_cstdio_file**) Data_custom_val(v)))

// finalizers must not use CAMLparam/CAMLreturn
void del_cpp_cstdio_file (value v) {
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(v);
    if (s) {
        // printf("delete file %llx\n", s);
        // a file dropped without fclose would leak its descriptor
        if (s->_file) { std::fclose(s->_file); }
        delete s;
    }
}

static struct custom_operations cpp_cstdio_file_ops = {
    (char *)"mlcpp_cstdio_file",
    del_cpp_cstdio_file,
    custom_compare_default,
    custom_hash_default,
    custom_serialize_default,
    custom_deserialize_default,
    custom_compare_ext_default,
    custom_fixed_length_default
};

void mk_file(value &res, _cpp_cstdio_file const &s) {
    res = caml_alloc_custom(&cpp_cstdio_file_ops,
                            sizeof(_cpp_cstdio_file*), 1, 40);
    CPP_CSTDIO_FILE(res) = nullptr;
    auto * cs = new (std::nothrow) _cpp_cstdio_file;
    if (! cs) {
        if (s._file) { std::fclose(s._file); }
        caml_raise_out_of_memory();
    }
    cs->_file = s._file;
    CPP_CSTDIO_FILE(res) = cs;
}

struct _cpp_cstdio_buffer {
    char *_buf {nullptr};
    long _len {0};
};

#define CPP_CSTDIO_BUFFER(v) (*((_cpp_cstdio_buffer**) Data_custom_val(v)))

// finalizers must not use CAMLparam/CAMLreturn
void del_cpp_cstdio_buffer (value v) {
    struct _cpp_cstdio_buffer *s = CPP_CSTDIO_BUFFER(v);
    if (s) {
        // printf("delete buffer[%ld]\n", s->_len);
        if (s->_buf) { free(s->_buf); }
        delete s;
    }
}

static struct custom_operations cpp_cstdio_buffer_ops = {
    (char *)"mlcpp_cstdio_buffer",
    del_cpp_cstdio_buffer,
    custom_compare_default,
    custom_hash_default,
    custom_serialize_default,
    custom_deserialize_default,
    custom_compare_ext_default,
    custom_fixed_length_default
};

void mk_buffer(value &res, _cpp_cstdio_buffer const &s) {
    // tell the GC how much C heap this buffer holds
    res = caml_alloc_custom_mem(&cpp_cstdio_buffer_ops,
                                sizeof(_cpp_cstdio_buffer*), s._len);
    CPP_CSTDIO_BUFFER(res) = nullptr;
    auto * cs = new (std::nothrow) _cpp_cstdio_buffer;
    if (! cs) {
        if (s._buf) { free(s._buf); }
        caml_raise_out_of_memory();
    }
    cs->_buf = s._buf;
    cs->_len = s._len;
    CPP_CSTDIO_BUFFER(res) = cs;
}

/*
 *   strerror_r is the XSI variant (returns int, fills buf) on macOS/musl
 *   and the GNU variant (returns char*, may not touch buf) on glibc with g++;
 *   overloading on the return type handles both.
 */
static const char *strerror_result(int r, const char *buf) { return r == 0 ? buf : "unknown error"; }
static const char *strerror_result(const char *r, const char *) { return r; }

static value mk_errstr(int e) {
    char buf[128] = {0};
    return caml_copy_string(strerror_result(strerror_r(e, buf, sizeof(buf)), buf));
}

#define mk_err_values(vtuple, verrno, verrstr, iserr) \
    if (iserr) { \
        /* errno 0 would read as success on the OCaml side */ \
        int e = errno ? errno : EIO; \
        verrno = Val_int(e); \
        verrstr = mk_errstr(e); \
    } else { \
        verrno = Val_int(0); \
        verrstr = caml_alloc_initialized_string(1, "-"); \
    } \
    vtuple = caml_alloc_tuple(2); \
    Store_field(vtuple, 0, verrno); \
    Store_field(vtuple, 1, verrstr); \

#define set_err_values(vtuple, eno, errstr) \
    verrno = Val_int(eno); \
    verrstr = caml_alloc_initialized_string(strnlen(errstr,64), errstr); \
    vtuple = caml_alloc_tuple(2); \
    Store_field(vtuple, 0, verrno); \
    Store_field(vtuple, 1, verrstr); \

/*
 *   valid_mode: only the modes defined by C11
 *   ("r", "w", "a", optionally with "+" and "b"; "x" only with "w")
 */
static bool valid_mode(const char *mode)
{
    if (mode[0] != 'r' && mode[0] != 'w' && mode[0] != 'a') { return false; }
    bool plus = false, bin = false, excl = false;
    for (const char *c = mode + 1; *c; c++) {
        if (*c == '+' && !plus) { plus = true; }
        else if (*c == 'b' && !bin) { bin = true; }
        else if (*c == 'x' && !excl && mode[0] == 'w') { excl = true; }
        else { return false; }
    }
    return true;
}

/*
 *   cpp_fopen : string -> string -> (fptr, (errorno, errstr))
 */
extern "C" {
value cpp_fopen(value vfn, value vmode)
{
    CAMLparam2(vfn, vmode);
    CAMLlocal2(res, cfile);
    CAMLlocal3(verrno, verrstr, t2);
    verrno = Val_int(0);
    struct _cpp_cstdio_file cs;
    if (! caml_string_is_c_safe(vfn)) {
        set_err_values(t2, EINVAL, "file name contains NUL");
    } else if (! caml_string_is_c_safe(vmode) || ! valid_mode(String_val(vmode))) {
        set_err_values(t2, EINVAL, "invalid mode");
    } else {
        cs._file = std::fopen(String_val(vfn), String_val(vmode));
        // printf("fopen => %llx (%d)\n", (void*)cs._file, errno);
        // read errno before mk_file allocates
        mk_err_values(t2, verrno, verrstr, (! cs._file));
    }
    mk_file(cfile, cs);
    res = caml_alloc_tuple(2);
    Store_field(res, 0, cfile);
    Store_field(res, 1, t2);
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fclose : fptr -> (errorno, errstr)
 */
extern "C" {
value cpp_fclose(value vfp)
{
    CAMLparam1(vfp);
    CAMLlocal3(res, verrno, verrstr);
    verrno = Val_int(0);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    int retval = 0;
    if (s && s->_file) {
        retval = std::fclose(s->_file);
        // the stream is gone even if fclose failed
        s->_file = nullptr;
        // printf("fclose on %llx (%d)\n", (void*)s->_file, errno);
        mk_err_values(res, verrno, verrstr, (retval != 0));
    } else {
        set_err_values(res, -99, "no FILE pointer");
    }
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fflush : fptr -> (errorno, errstr)
 */
extern "C" {
value cpp_fflush(value vfp)
{
    CAMLparam1(vfp);
    CAMLlocal3(res, verrno, verrstr);
    verrno = Val_int(0);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    int retval = 0;
    if (s && s->_file) {
        retval = std::fflush(s->_file);
        mk_err_values(res, verrno, verrstr, (retval != 0));
    } else {
        set_err_values(res, -99, "no FILE pointer");
    }
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fflush_all : unit -> (errorno, errstr)
 */
extern "C" {
value cpp_fflush_all(value unit)
{
    CAMLparam1(unit);
    CAMLlocal3(res, verrno, verrstr);
    verrno = Val_int(0);
    int retval = 0;
    retval = std::fflush(nullptr);
    mk_err_values(res, verrno, verrstr, (retval != 0));
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_ftell : fptr -> (int, (errorno, errstr))
 */
extern "C" {
value cpp_ftell(value vfp)
{
    CAMLparam1(vfp);
    CAMLlocal1(res);
    CAMLlocal3(verrno, verrstr, t2);
    verrno = Val_int(0);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    long floc = 0;
    if (s && s->_file) {
        floc = std::ftell(s->_file);
        mk_err_values(t2, verrno, verrstr, (floc < 0));
    } else {
        set_err_values(t2, -99, "no FILE pointer");
    }
    res = caml_alloc_tuple(2);
    Store_field(res, 0, Val_long(floc));
    Store_field(res, 1, t2);
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fseek : fptr -> int -> (errorno, errstr)
 */
extern "C" {
value cpp_fseek(value vfp, value voff)
{
    CAMLparam2(vfp, voff);
    CAMLlocal3(res, verrno, verrstr);
    verrno = Val_int(0);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    long off = Long_val(voff);
    int retval = 0;
    if (s && s->_file) {
        retval = std::fseek(s->_file, off, SEEK_SET);
        mk_err_values(res, verrno, verrstr, (retval != 0));
    } else {
        set_err_values(res, -99, "no FILE pointer");
    }
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fseek_relative : fptr -> int -> (errorno, errstr)
 */
extern "C" {
value cpp_fseek_relative(value vfp, value voff)
{
    CAMLparam2(vfp, voff);
    CAMLlocal3(res, verrno, verrstr);
    verrno = Val_int(0);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    long off = Long_val(voff);
    int retval = 0;
    if (s && s->_file) {
        retval = std::fseek(s->_file, off, SEEK_CUR);
        mk_err_values(res, verrno, verrstr, (retval != 0));
    } else {
        set_err_values(res, -99, "no FILE pointer");
    }
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fseek_end : fptr -> int -> (errorno, errstr)
 */
extern "C" {
value cpp_fseek_end(value vfp, value voff)
{
    CAMLparam2(vfp, voff);
    CAMLlocal3(res, verrno, verrstr);
    verrno = Val_int(0);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    long off = Long_val(voff);
    int retval = 0;
    if (s && s->_file) {
        retval = std::fseek(s->_file, off, SEEK_END);
        mk_err_values(res, verrno, verrstr, (retval != 0));
    } else {
        set_err_values(res, -99, "no FILE pointer");
    }
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fread : ta -> int -> fptr -> (int, (errorno, errstr))
 */
extern "C" {
value cpp_fread(value vbuf, value vn, value vfp)
{
    CAMLparam3(vbuf, vn, vfp);
    CAMLlocal2(res, vcnt);
    CAMLlocal3(verrno, verrstr, t2);
    verrno = Val_int(0);
    long cnt = 0;
    struct _cpp_cstdio_buffer *b = CPP_CSTDIO_BUFFER(vbuf);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    if (b == NULL || b->_buf == NULL) {
        set_err_values(t2, -1, "no buffer");
    } else if (Long_val(vn) < 0) {
        set_err_values(t2, -1, "invalid length");
    } else if (s == NULL || s->_file == NULL) {
        set_err_values(t2, -99, "no FILE pointer");
    } else {
        size_t n = (size_t)std::min(b->_len, Long_val(vn));
        char *tgt = b->_buf;
        cnt = std::fread(tgt, 1, n, s->_file);
        // end of file is not an error: a short count, 0 at the end
        mk_err_values(t2, verrno, verrstr, (ferror(s->_file) != 0));
    }
    res = caml_alloc_tuple(2);
    Store_field(res, 0, Val_long(cnt));
    Store_field(res, 1, t2);
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fwrite : ta -> int -> fptr -> (int, (errorno, errstr))
 */
extern "C" {
value cpp_fwrite(value vbuf, value vn, value vfp)
{
    CAMLparam3(vbuf, vn, vfp);
    CAMLlocal2(res, vcnt);
    CAMLlocal3(verrno, verrstr, t2);
    verrno = Val_int(0);
    long cnt = 0;
    struct _cpp_cstdio_buffer *b = CPP_CSTDIO_BUFFER(vbuf);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    if (b == NULL || b->_buf == NULL) {
        set_err_values(t2, -1, "no buffer");
    } else if (Long_val(vn) < 0) {
        set_err_values(t2, -1, "invalid length");
    } else if (s == NULL || s->_file == NULL) {
        set_err_values(t2, -99, "no FILE pointer");
    } else {
        const char *src = b->_buf;
        long n = std::min(b->_len, Long_val(vn));
        cnt = std::fwrite(src, 1, (size_t)n, s->_file);
        mk_err_values(t2, verrno, verrstr, (cnt < n));
    }
    res = caml_alloc_tuple(2);
    Store_field(res, 0, Val_long(cnt));
    Store_field(res, 1, t2);
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_fwrite_s : string -> fptr -> (int, (errorno, errstr))
 */
extern "C" {
value cpp_fwrite_s(value vs, value vfp)
{
    CAMLparam2(vs, vfp);
    CAMLlocal2(res, vcnt);
    CAMLlocal3(verrno, verrstr, t2);
    verrno = Val_int(0);
    long cnt = 0;
    const char *msg = String_val(vs);
    const long n = caml_string_length(vs);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    if (s == NULL || s->_file == NULL) {
        set_err_values(t2, -99, "no FILE pointer");
    } else {
        cnt = std::fwrite(msg, 1, (size_t)n, s->_file);
        mk_err_values(t2, verrno, verrstr, (cnt < n));
    }
    res = caml_alloc_tuple(2);
    Store_field(res, 0, Val_long(cnt));
    Store_field(res, 1, t2);
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_ferror : file -> (errorno, errstr)
 */
extern "C" {
value cpp_ferror(value vfp)
{
    CAMLparam1(vfp);
    CAMLlocal3(res, verrno, verrstr);
    verrno = Val_int(0);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    if (s && s->_file) {
        int err = ferror(s->_file);
        mk_err_values(res, verrno, verrstr, err != 0);
    } else {
        set_err_values(res, -99, "no FILE pointer");
    }
    CAMLreturn(res);
}
} // extern C

/*
 *   cpp_feof : file -> bool
 */
extern "C" {
value cpp_feof(value vfp)
{
    CAMLparam1(vfp);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    // a closed or failed file has no more data to read
    bool res = (s == NULL || s->_file == NULL) || feof(s->_file) != 0;
    CAMLreturn(Val_bool(res));
}
} // extern C

/*
 *  cpp_copy_sz_pos: copy data between buffers
 */
extern "C" {
value cpp_copy_sz_pos(value vbuf1, value vpos1, value vsz, value vbuf2, value vpos2)
{
    CAMLparam5(vbuf1, vpos1, vsz, vbuf2, vpos2);
    long sz = Long_val(vsz);
    if (sz < 0) { CAMLreturn(Val_long(-3)); }
    long pos1 = Long_val(vpos1);
    if (pos1 < 0) { CAMLreturn(Val_long(-4)); }
    struct _cpp_cstdio_buffer *cb1 = CPP_CSTDIO_BUFFER(vbuf1);
    // test if enough bytes can be copied from source (written to not overflow)
    if (cb1 == NULL || cb1->_buf == NULL || pos1 > cb1->_len || sz > cb1->_len - pos1) { CAMLreturn(Val_long(-1)); }
    struct _cpp_cstdio_buffer *cb2 = CPP_CSTDIO_BUFFER(vbuf2);
    long pos2 = Long_val(vpos2);
    if (pos2 < 0) { CAMLreturn(Val_long(-5)); }
    // test if the target can accept enough bytes
    if (cb2 == NULL || cb2->_buf == NULL || pos2 > cb2->_len || sz > cb2->_len - pos2) { CAMLreturn(Val_long(-2)); }
    std::memmove(cb2->_buf+pos2, cb1->_buf+pos1, sz);
    CAMLreturn(Val_long(sz));
}
} // extern C

/*
 *  cpp_buffer_create: create buffers
 */
extern "C" {
value cpp_buffer_create(value vsz)
{
    CAMLparam1(vsz);
    CAMLlocal1(res);
    long sz = Long_val(vsz);
    if (sz < 0) { caml_invalid_argument("Buffer.create: negative size"); }
    struct _cpp_cstdio_buffer cb;
    cb._buf = (char*)calloc(sz, 1);
    cb._len = cb._buf?sz:0;
    // printf("create new buffer[%ld]\n", sz);
    mk_buffer(res, cb);
    CAMLreturn(res);
}
} // extern C

/*
 *  cpp_buffer_relase: release buffers
 */
extern "C" {
value cpp_buffer_release(value vbuf)
{
    CAMLparam1(vbuf);
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    if (cb) {
        if (cb->_buf) {
            free(cb->_buf);
            cb->_buf = NULL;
        }
        cb->_len = 0;
    }
    CAMLreturn(vbuf);
}
} // extern C

/*
 *  cpp_buffer_resize: reallocate buffers
 */
extern "C" {
value cpp_buffer_resize(value vbuf, value vsz)
{
    CAMLparam2(vbuf, vsz);
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    long sz = Long_val(vsz);
    if (cb && cb->_buf && sz > 0 && sz > cb->_len) {
        void *p = realloc(cb->_buf, sz);
        if (p) {
            cb->_buf = (char*)p;
            cb->_len = sz;
        } else {
            fprintf(stderr, "realloc error: %d %s\n", errno, strerror(errno));
        }
    }
    CAMLreturn(Val_unit);
}
} // extern C

/*
 *  cpp_buffer_good: is buffer ok?
 */
extern "C" {
value cpp_buffer_good(value vbuf)
{
    // [@@noalloc]: no CAMLparam
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    return Val_bool(cb != NULL && cb->_buf != NULL && cb->_len > 0);
}
} // extern C

/*
 *  cpp_buffer_size: length of buffer
 */
extern "C" {
value cpp_buffer_size(value vbuf)
{
    // [@@noalloc]: no CAMLparam
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    return Val_long(cb ? cb->_len : 0);
}
} // extern C

/*
 *  cpp_buffer_get: get char at index of buffer
 */
extern "C" {
value cpp_buffer_get(value vbuf, value vidx)
{
    CAMLparam2(vbuf,vidx);
    const struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    long idx = Long_val(vidx);
    if (! (cb && cb->_buf && idx >= 0 && idx < cb->_len)) {
        caml_invalid_argument("Buffer.get: index out of bounds");
    }
    // unsigned: bytes >= 0x80 must stay in 0..255 to be a valid OCaml char
    unsigned char ch = (unsigned char)cb->_buf[idx];
    CAMLreturn(Val_int(ch));
}
} // extern C

/*
 *  cpp_buffer_set: set char at index of buffer
 */
extern "C" {
value cpp_buffer_set(value vbuf, value vidx, value vch)
{
    CAMLparam3(vbuf,vidx,vch);
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    long idx = Long_val(vidx);
    int ch = Int_val(vch);
    if (! (cb && cb->_buf && idx >= 0 && idx < cb->_len)) {
        caml_invalid_argument("Buffer.set: index out of bounds");
    }
    cb->_buf[idx] = (char)ch;
    CAMLreturn(Val_unit);
}
} // extern C

/*
 *  cpp_copy_string: copy string into buffer at position
 */
extern "C" {
value cpp_copy_string(value vs, value vbuf, value vidx)
{
    CAMLparam3(vs,vbuf,vidx);
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    long idx = Long_val(vidx);
    long ls = caml_string_length(vs);
    const char * str = String_val(vs);
    // written to not overflow: idx <= len, then ls <= len - idx
    if (! (str && cb && cb->_buf && idx >= 0 && idx <= cb->_len && ls <= cb->_len - idx)) {
        caml_invalid_argument("Buffer.copy_string: out of bounds");
    }
    memcpy(cb->_buf+idx, str, ls);
    CAMLreturn(Val_unit);
}
} // extern C

/*
 *  cpp_buffer_to_string: copy the buffer into a new string
 */
extern "C" {
value cpp_buffer_to_string(value vbuf)
{
    CAMLparam1(vbuf);
    CAMLlocal1(res);
    // the C heap block does not move when the GC runs
    const struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    if (cb && cb->_buf && cb->_len > 0) {
        res = caml_alloc_initialized_string(cb->_len, cb->_buf);
    } else {
        res = caml_alloc_string(0);
    }
    CAMLreturn(res);
}
} // extern C

/*
 *  cpp_buffer_sub_string: copy len bytes at pos into a new string
 */
extern "C" {
value cpp_buffer_sub_string(value vbuf, value vpos, value vlen)
{
    CAMLparam3(vbuf, vpos, vlen);
    CAMLlocal1(res);
    const struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    long pos = Long_val(vpos);
    long len = Long_val(vlen);
    long blen = cb ? cb->_len : 0;
    // written to not overflow: pos <= blen, then len <= blen - pos
    if (pos < 0 || len < 0 || pos > blen || len > blen - pos) {
        caml_invalid_argument("Buffer.sub_string: out of bounds");
    }
    if (len == 0) {
        res = caml_alloc_string(0);
    } else {
        res = caml_alloc_initialized_string(len, cb->_buf + pos);
    }
    CAMLreturn(res);
}
} // extern C

/*
 *  cpp_buffer_from_string: create a buffer holding a copy of the string
 */
extern "C" {
value cpp_buffer_from_string(value vs)
{
    CAMLparam1(vs);
    CAMLlocal1(res);
    long len = caml_string_length(vs);
    struct _cpp_cstdio_buffer cb;
    cb._buf = (char*)calloc(len, 1);
    if (len > 0 && ! cb._buf) { caml_raise_out_of_memory(); }
    // copy before mk_buffer allocates: the GC may move the string
    if (len > 0) { std::memcpy(cb._buf, String_val(vs), len); }
    cb._len = cb._buf ? len : 0;
    mk_buffer(res, cb);
    CAMLreturn(res);
}
} // extern C
