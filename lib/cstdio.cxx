
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
        // printf("delete timepoint %llx\n", s);
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
                            sizeof(_cpp_cstdio_file*), 1, 1000);
    auto * cs = new _cpp_cstdio_file;
    cs->_file = s._file;
    CPP_CSTDIO_FILE(res) = cs;
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
value cpp_fread(value varr, value vn, value vfp)
{
    CAMLparam3(varr, vn, vfp);
    CAMLlocal2(res, vcnt);
    CAMLlocal3(verrno, verrstr, t2);
    verrno = Val_int(0);
    char *tgt = (char *)Caml_ba_data_val(varr);
    long n = Long_val(vn);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    long cnt = std::fread(tgt, 1, n, s->_file);
    if (feof(s->_file) != 0) {
        set_err_values(t2, -42, "EOF");
    } else {
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
value cpp_fwrite(value varr, value vn, value vfp)
{
    CAMLparam3(varr, vn, vfp);
    CAMLlocal2(res, vcnt);
    CAMLlocal3(verrno, verrstr, t2);
    verrno = Val_int(0);
    const char *src = (const char *)Caml_ba_data_val(varr);
    long n = Long_val(vn);
    struct _cpp_cstdio_file *s = CPP_CSTDIO_FILE(vfp);
    long cnt = std::fwrite(src, 1, n, s->_file);
    mk_err_values(t2, verrno, verrstr, (cnt < n));
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
value cpp_copy_sz_pos(value varr1, value vsz, value vpos, value varr2)
{
    CAMLparam4(varr1, vsz, vpos, varr2);
    CAMLlocal1(res);
    long sz = Long_val(vsz);
    const char *src = (const char *)Caml_ba_data_val(varr1);
    unsigned long l1 = caml_ba_byte_size(Caml_ba_array_val(varr1));
    if (l1 < sz) { return Val_long(-1); }   // test if enough bytes can be copied from source
    char *tgt = (char *)Caml_ba_data_val(varr2);
    unsigned long l2 = caml_ba_byte_size(Caml_ba_array_val(varr2));
    long pos = Long_val(vpos);
    if (l2 < pos + sz) { return Val_long(-2); }  // test if the target can accept enough bytes
    std::memcpy(tgt+pos, src, sz);
    CAMLreturn(Val_long(sz));
}
} // extern C
