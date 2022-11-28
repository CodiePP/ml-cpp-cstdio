
// OCaml includes
extern "C" {
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/custom.h>
// #include <caml/callback.h>
#include <caml/fail.h>

#include <sys/errno.h>
} //extern C

// C++ includes
#include <algorithm>
#include <cstdio>
#include <cstring>

struct _cpp_cstdio_file {
    FILE *_file {nullptr};
};

#define CPP_CSTDIO_FILE(v) (*((_cpp_cstdio_file**) Data_custom_val(v)))

void del_cpp_cstdio_file (value v) {
    CAMLparam1(v);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(v);
    if (s) {
        // printf("delete file %llx\n", s);
        delete s;
    }
    CAMLreturn0;
}

static struct custom_operations cpp_cstdio_file_ops = {
    (char *)"mlcpp_cstdio_file",
    del_cpp_cstdio_file,
    custom_compare_default,
    custom_hash_default,
    custom_serialize_default,
    custom_deserialize_default
};

void mk_file(value &res, _cpp_cstdio_file const &s) {
    res = caml_alloc_custom(&cpp_cstdio_file_ops,
                            sizeof(_cpp_cstdio_file*), 1, 40);
    auto * cs = new _cpp_cstdio_file;
    cs->_file = s._file;
    CPP_CSTDIO_FILE(res) = cs;
}

struct _cpp_cstdio_buffer {
    char *_buf {nullptr};
    long _len {0};
};

#define CPP_CSTDIO_BUFFER(v) (*((_cpp_cstdio_buffer**) Data_custom_val(v)))

void del_cpp_cstdio_buffer (value v) {
    CAMLparam1(v);
    struct _cpp_cstdio_buffer *s = CPP_CSTDIO_BUFFER(v);
    if (s) {
        // printf("delete buffer[%ld]\n", s->_len);
        if (s->_buf) { free(s->_buf); }
        delete s;
    }
    CAMLreturn0;
}

static struct custom_operations cpp_cstdio_buffer_ops = {
    (char *)"mlcpp_cstdio_buffer",
    del_cpp_cstdio_buffer,
    custom_compare_default,
    custom_hash_default,
    custom_serialize_default,
    custom_deserialize_default
};

void mk_buffer(value &res, _cpp_cstdio_buffer const &s) {
    res = caml_alloc_custom(&cpp_cstdio_buffer_ops,
                            sizeof(_cpp_cstdio_buffer*), 1, 10);
    auto * cs = new _cpp_cstdio_buffer;
    cs->_buf = s._buf;
    cs->_len = s._len;
    CPP_CSTDIO_BUFFER(res) = cs;
}

#define mk_err_values(vtuple, verrno, verrstr, iserr) \
    if (iserr) { \
        verrno = Val_int(errno); \
        char buf[64]; memset(buf, 0, 64); \
        strerror_r(errno, buf, 63); \
        verrstr = caml_alloc_initialized_string(strnlen(buf,64), buf); \
    } else { \
        verrno = Val_int(0); \
        verrstr = caml_alloc_initialized_string(1, "-"); \
    } \
    vtuple = caml_alloc_tuple(2); \
    Store_field(vtuple, 0, verrno); \
    Store_field(vtuple, 1, verrstr); \

#define set_err_values(vtuple, errno, errstr) \
    verrno = Val_int(errno); \
    verrstr = caml_alloc_initialized_string(strnlen(errstr,64), errstr); \
    vtuple = caml_alloc_tuple(2); \
    Store_field(vtuple, 0, verrno); \
    Store_field(vtuple, 1, verrstr); \

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
    const char *fn = String_val(vfn);
    const char *mode = String_val(vmode);
    struct _cpp_cstdio_file cs;
    cs._file = std::fopen(fn, mode);
    // printf("fopen => %llx (%d)\n", (void*)cs._file, errno);
    mk_file(cfile, cs);
    mk_err_values(t2, verrno, verrstr, (! cs._file));
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
    if (b == NULL || b->_buf == NULL) {
        set_err_values(t2, -1, "no buffer");
    } else {
        long n = std::min(b->_len, Long_val(vn));
        char *tgt = b->_buf;
        struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
        cnt = std::fread(tgt, 1, n, s->_file);
        if (cnt <= 0 && feof(s->_file) != 0) {
            set_err_values(t2, -42, "EOF");
        } else {
            mk_err_values(t2, verrno, verrstr, (ferror(s->_file) != 0));
        }
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
    if (b == NULL || b->_buf == NULL) {
        set_err_values(t2, -1, "no buffer");
    } else {
        const char *src = b->_buf;
        long n = std::min(b->_len, Long_val(vn));
        struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
        cnt = std::fwrite(src, 1, n, s->_file);
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
    if (msg == NULL || n < 0) {
        set_err_values(t2, -1, "empty string");
    } else {
        struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
        cnt = std::fwrite(msg, 1, n, s->_file);
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
    int err = ferror(s->_file);
    mk_err_values(res, verrno, verrstr, err != 0);
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
    bool res = feof(s->_file) != 0;
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
    CAMLlocal1(res);
    long sz = Long_val(vsz);
    if (sz < 0) { return Val_long(-3); }
    long pos1 = Long_val(vpos1);
    if (pos1 < 0) { return Val_long(-4); }
    struct _cpp_cstdio_buffer *cb1 = CPP_CSTDIO_BUFFER(vbuf1);
    if (cb1->_len < sz + pos1) { return Val_long(-1); }   // test if enough bytes can be copied from source
    struct _cpp_cstdio_buffer *cb2 = CPP_CSTDIO_BUFFER(vbuf2);
    long pos2 = Long_val(vpos2);
    if (pos2 < 0) { return Val_long(-5); }
    if (cb2->_len < pos2 + sz) { return Val_long(-2); }  // test if the target can accept enough bytes
    std::memcpy(cb2->_buf+pos2, cb1->_buf+pos1, sz);
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
    if (cb->_buf) {
        free(cb->_buf);
        cb->_buf = NULL;
    }
    cb->_len = 0;
    CPP_CSTDIO_BUFFER(vbuf) = cb;
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
    if (sz > 0 && sz > cb->_len && cb->_buf) {
        void *p = realloc(cb->_buf, sz);
        if (p) {
            cb->_buf = (char*)p;
            cb->_len = cb->_buf?sz:0;
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
    CAMLparam1(vbuf);
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    CAMLreturn(Val_bool(cb != NULL && cb->_buf != NULL && cb->_len > 0));
}
} // extern C

/*
 *  cpp_buffer_size: length of buffer
 */
extern "C" {
value cpp_buffer_size(value vbuf)
{
    CAMLparam1(vbuf);
    struct _cpp_cstdio_buffer *cb = CPP_CSTDIO_BUFFER(vbuf);
    CAMLreturn(Val_long(cb->_len));
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
    int ch = -1;
    if (cb && cb->_buf && idx >= 0 && idx < cb->_len) {
        ch = cb->_buf[idx];
    }
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
    if (cb && cb->_buf && idx >= 0 && idx < cb->_len) {
        cb->_buf[idx] = (char)ch;
    }
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
    if (str && cb->_buf && ls + idx <= cb->_len) {
        memcpy(cb->_buf+idx, str, ls);
    }
    CAMLreturn(Val_unit);
}
} // extern C
