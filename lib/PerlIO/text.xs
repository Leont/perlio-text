#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "perliol.h"

static IV PerlIOText_pushed(pTHX_ PerlIO *f, const char *mode, SV *arg, PerlIO_funcs *tab) {
	if (!arg || !SvOK(arg)) {
		SETERRNO(EINVAL, LIB_INVARG);
		return -1;
	}
	PerlIO_apply_layers(aTHX_ f, mode, ":raw");
	PerlIO_funcs* encoding = PerlIO_find_layer(aTHX_ "encoding", 8, 1);
	if (PerlIO_push(aTHX_ f, encoding, mode, arg) != f)
		return -1;
#ifdef PERLIO_USING_CRLF
    PerlIO_funcs* crlf = PerlIO_find_layer(aTHX_ "crlf", 4, 0);
    if (PerlIO_push(aTHX_ f, crlf, mode, &PL_sv_undef) != f)
		return -1;
#endif
	return f ? 0 : -1;
}

static PerlIO* PerlIOText_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n, const char* mode, int fd, int imode, int perm, PerlIO* f, int narg, SV** args) {
#if defined(PERLIO_USING_CRLF) && PERL_VERSION < 14
//	if (layers->array[n - 1].funcs == PerlIO_crlf)
		layers->array[n - 1].funcs = &PerlIO_perlio;
#endif
	PerlIO_funcs * const tab = PerlIO_layer_fetch(aTHX_ layers, n - 1, NULL);
	if (tab && tab->Open) {
		PerlIO* ret = (*tab->Open)(aTHX_ tab, layers, n - 1, mode, fd, imode, perm, f, narg, args);
		if (ret && PerlIO_push(aTHX_ ret, self, mode, PerlIOArg) == NULL) {
			PerlIO_close(ret);
			return NULL;
		}
		return ret;
	}
}

const PerlIO_funcs PerlIO_text = {
	sizeof(PerlIO_funcs),
	"text",
	0,
	PERLIO_K_UTF8 | PERLIO_K_MULTIARG,
	PerlIOText_pushed,
	NULL,
	PerlIOText_open,
};

MODULE = PerlIO::text				PACKAGE = PerlIO::text

BOOT:
	PerlIO_define_layer(aTHX_ (PerlIO_funcs*)&PerlIO_text);
