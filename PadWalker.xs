#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* For 5.005 compatibility */
#ifndef aTHX_
#  define aTHX_
#endif
#ifndef pTHX_
#  define pTHX_
#endif
#ifndef pTHX
#  define pTHX
#endif
#ifndef aTHX
#  define aTHX
#endif
#ifndef CxTYPE
#  define CxTYPE(cx) ((cx)->cx_type)
#endif

/* Originally stolen from pp_ctl.c; now significantly different */

I32
dopoptosub_at(pTHX_ PERL_CONTEXT *cxstk, I32 startingblock)
{
    dTHR;
    I32 i;
    PERL_CONTEXT *cx;
    for (i = startingblock; i >= 0; i--) {
        cx = &cxstk[i];
        switch (CxTYPE(cx)) {
        default:
            continue;
        /* case CXt_EVAL: */
        case CXt_SUB:
    	/* In Perl 5.005, formats just used CXt_SUB */
#ifdef CXt_FORMAT
        case CXt_FORMAT:
#endif
            DEBUG_l( Perl_deb(aTHX_ "(Found sub #%ld)\n", (long)i));
            return i;
        }
    }
    return i;
}

I32
dopoptosub(pTHX_ I32 startingblock)
{
    dTHR;
    return dopoptosub_at(aTHX_ cxstack, startingblock);
}

PERL_CONTEXT*
upcontext(pTHX_ I32 count, U32 *cop_seq_p, PERL_CONTEXT **ccstack_p, I32 *cxix_p)
{
    PERL_SI *top_si = PL_curstackinfo;
    I32 cxix = dopoptosub(aTHX_ cxstack_ix);
    PERL_CONTEXT *cx;
    PERL_CONTEXT *ccstack = cxstack;
    I32 dbcxix;

    for (;;) {
        /* we may be in a higher stacklevel, so dig down deeper */
        while (cxix < 0 && top_si->si_type != PERLSI_MAIN) {
            top_si  = top_si->si_prev;
            ccstack = top_si->si_cxstack;
            cxix = dopoptosub_at(aTHX_ ccstack, top_si->si_cxix);
        }
        if (cxix < 0 && count == 0) {
            if (ccstack_p) *ccstack_p = ccstack;
            if (cxix_p)    *cxix_p    = 1;
            return (PERL_CONTEXT *)0;
        }
        else if (cxix < 0) {
            return (PERL_CONTEXT *)-1;
        }
        if (PL_DBsub && cxix >= 0 &&
                ccstack[cxix].blk_sub.cv == GvCV(PL_DBsub))
            count++;
        if (!count--)
            break;

        if (cop_seq_p) *cop_seq_p = ccstack[cxix].blk_oldcop->cop_seq;
        cxix = dopoptosub_at(aTHX_ ccstack, cxix - 1);
    }
    if (ccstack_p) *ccstack_p = ccstack;
    if (cxix_p)    *cxix_p    = cxix;
    return &ccstack[cxix];
}

/* end thievery */

void
pads_into_hash(AV* pad_namelist, AV* pad_vallist, HV* hash, U32 valid_at_seq)
{
    I32 i;

    for (i=0; i<=av_len(pad_namelist); ++i) {
      SV** name_ptr = av_fetch(pad_namelist, i, 0);

      if (name_ptr) {
        SV*   name_sv = *name_ptr;

	if (SvPOKp(name_sv)) {
          char* name_str = SvPVX(name_sv);

        /* printf("%s (%x,%x) [%x]\n", name_str, I_32(SvNVX(name_sv)), SvIVX(name_sv),
                                    valid_at_seq); */
        

        /* Check that this variable is valid at the cop_seq
         * specified, by peeking into the NV and IV slots
         * of the name sv. (This must be one of those "breathtaking
         * optimisations" mentioned in the Panther book).

         * Anonymous subs are stored here with a name of "&",
         * so also check that the name is longer than one char.
         * (Note that the prefix letter is here as well, so a
         * valid variable will _always_ be >1 char)
         */

        if ((0 == valid_at_seq || (valid_at_seq <= SvIVX(name_sv) &&
            valid_at_seq > I_32(SvNVX(name_sv)))) &&
            strlen(name_str) > 1 )

	    hv_store(hash, name_str, strlen(name_str),
                     newRV_inc(*av_fetch(pad_vallist, i, 0)), 0);

        }
      }
    }
}

void
padlist_into_hash(AV* padlist, HV* hash, U32 valid_at_seq, U16 depth)
{
    /* We blindly deref this, cos it's always there (AFAIK!) */
    AV* pad_namelist = (AV*) *av_fetch(padlist, 0, FALSE);
    AV* pad_vallist  = (AV*) *av_fetch(padlist, depth, FALSE);

    pads_into_hash(pad_namelist, pad_vallist, hash, valid_at_seq);
}

void
context_vars(PERL_CONTEXT *cx, HV* ret, U32 seq)
{
    if (cx == (PERL_CONTEXT*)-1)
        croak("Not nested deeply enough");
    else if (!cx && !PL_compcv)
        pads_into_hash(PL_comppad_name, PL_comppad, ret, seq);

    else {
        CV* cur_cv = cx ? cx->blk_sub.cv           : PL_compcv;
        U16 depth  = cx ? cx->blk_sub.olddepth + 1 : 1;

        if (!cur_cv)
            die("panic: Context has no CV!\n");
    
        while (cur_cv) {
            /* printf("cv name = %s; seq=%x; depth=%d\n",
                      CvGV(cur_cv) ? GvNAME(CvGV(cur_cv)) : "(null)", seq, depth); */
            padlist_into_hash(CvPADLIST(cur_cv), ret, seq, depth);
            cur_cv = CvOUTSIDE(cur_cv);
            if (cur_cv) depth  = CvDEPTH(cur_cv);
        }
    }
}

MODULE = PadWalker		PACKAGE = PadWalker
PROTOTYPES: DISABLE		

void
peek_my(uplevel)
I32 uplevel;
  PREINIT:
    HV* ret = newHV();
    PERL_CONTEXT *cx, *ccstack;
    U32 seq = PL_curcop->cop_seq;
    I32 cxix;
    bool saweval = FALSE;

  PPCODE:
    cx = upcontext(aTHX_ uplevel, &seq, &ccstack, &cxix);
    context_vars(cx, ret, seq);

    for (; cxix >= 0; --cxix) {
        switch (CxTYPE(&ccstack[cxix])) {
      
        case CXt_EVAL:
            switch(ccstack[cxix].blk_eval.old_op_type) {
            case OP_ENTEREVAL:
                /* printf("Found eval: %d\n", cxix); */
                saweval = TRUE;
                seq = ccstack[cxix].blk_oldcop->cop_seq;
                break;
            case OP_REQUIRE:
                goto END;
            }
            break;

        case CXt_SUB:
#ifdef CXt_FORMAT
        case CXt_FORMAT:
#endif
            if (!saweval) goto END;
            context_vars(&ccstack[cxix], ret, seq);

        default:
            if (cxix == 0 && saweval) {
                padlist_into_hash(CvPADLIST(PL_main_cv), ret, seq, 1);
            }
        }
    }

 END:
    EXTEND(SP, 1);
    PUSHs(sv_2mortal(newRV_noinc((SV*)ret)));

void
peek_sub(cur_sv)
SV* cur_sv;
  PREINIT:
    CV* cur_cv = (CV*)SvRV(cur_sv);
    HV* ret = newHV();
    AV* cv_padlist;
  PPCODE:
    padlist_into_hash(CvPADLIST(cur_cv), ret, 0, CvDEPTH(cur_cv));
    EXTEND(SP, 1);
    PUSHs(sv_2mortal(newRV_noinc((SV*)ret)));

void
_upcontext(uplevel)
I32 uplevel
  PPCODE:
    XPUSHs(sv_2mortal(newSViv((U32)upcontext(uplevel, 0, 0, 0))));
