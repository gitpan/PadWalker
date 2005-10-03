#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* For development testing */
#ifdef PADWALKER_DEBUGGING
# define debug_print(x) printf x
#else
# define debug_print(x)
#endif

#define HAS_EVAL_CV (\
  PERL_REVISION > 5 || \
  (PERL_REVISION == 5 && PERL_VERSION >= 8))

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

/* For debugging */
#ifdef PADWALKER_DEBUGGING
char *
cxtype_name(U32 cx_type)
{
  switch(cx_type & CXTYPEMASK)
  {
    case CXt_NULL:   return "null";
    case CXt_SUB:    return "sub";
    case CXt_EVAL:   return "eval";
    case CXt_LOOP:   return "loop";
    case CXt_SUBST:  return "subst";
    case CXt_BLOCK:  return "block";
    case CXt_FORMAT: return "format";

    default:         debug_print(("Unknown context type 0x%x\n", cx_type));
					 return "(unknown)";
  }
}

void
show_cxstack(void)
{
	I32 i;
    for (i = cxstack_ix; i>=0; --i)
    {
		printf(" =%ld= %s (%x)", (long)i,
				cxtype_name(CxTYPE(&cxstack[i])), cxstack[i].blk_oldcop->cop_seq);
        if (CxTYPE(&cxstack[i]) == CXt_SUB) {
		  CV *cv = cxstack[i].blk_sub.cv;
		  printf("\t%s", (cv && CvGV(cv)) ? GvNAME(CvGV(cv)) :"(null)");
		}
		printf("\n");
    }
}
#else
# define show_cxstack()
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
        case CXt_SUB:
    	/* In Perl 5.005, formats just used CXt_SUB */
#ifdef CXt_FORMAT
       case CXt_FORMAT:
#endif
            debug_print(("**dopoptosub_at: found sub #%ld\n", (long)i));
            return i;
        }
    }
	debug_print(("**dopoptosub_at: not found #%ld\n", (long)i));
    return i;
}

I32
dopoptosub(pTHX_ I32 startingblock)
{
    dTHR;
    return dopoptosub_at(aTHX_ cxstack, startingblock);
}

/* This function is based on the code of pp_caller */
PERL_CONTEXT*
upcontext(pTHX_ I32 count, COP **cop_p, PERL_CONTEXT **ccstack_p,
				I32 *cxix_from_p, I32 *cxix_to_p)
{
    PERL_SI *top_si = PL_curstackinfo;
    I32 cxix = dopoptosub(aTHX_ cxstack_ix);
    PERL_CONTEXT *cx;
    PERL_CONTEXT *ccstack = cxstack;
    I32 dbcxix;

	if (cxix_from_p) *cxix_from_p = cxstack_ix+1;
	if (cxix_to_p)   *cxix_to_p   = cxix;
    for (;;) {
        /* we may be in a higher stacklevel, so dig down deeper */
        while (cxix < 0 && top_si->si_type != PERLSI_MAIN) {
            top_si  = top_si->si_prev;
            ccstack = top_si->si_cxstack;
            cxix = dopoptosub_at(aTHX_ ccstack, top_si->si_cxix);
			if (cxix_to_p && cxix_from_p) *cxix_from_p = *cxix_to_p;
			if (cxix_to_p) *cxix_to_p = cxix;
        }
        if (cxix < 0 && count == 0) {
		    if (ccstack_p) *ccstack_p = ccstack;
            return (PERL_CONTEXT *)0;
		}
        else if (cxix < 0)
            return (PERL_CONTEXT *)-1;
        if (PL_DBsub && cxix >= 0 &&
                ccstack[cxix].blk_sub.cv == GvCV(PL_DBsub))
            count++;
        if (!count--)
            break;

        if (cop_p) *cop_p = ccstack[cxix].blk_oldcop;
        cxix = dopoptosub_at(aTHX_ ccstack, cxix - 1);
			if (cxix_to_p && cxix_from_p) *cxix_from_p = *cxix_to_p;
			if (cxix_to_p) *cxix_to_p = cxix;
    }
    if (ccstack_p) *ccstack_p = ccstack;
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

        debug_print(("** %s (%x,%x) [%x]%s\n", name_str,
               I_32(SvNVX(name_sv)), SvIVX(name_sv), valid_at_seq,
               SvFAKE(name_sv) ? " <fake>" : ""));
        
        /* Check that this variable is valid at the cop_seq
         * specified, by peeking into the NV and IV slots
         * of the name sv. (This must be one of those "breathtaking
         * optimisations" mentioned in the Panther book).

         * Anonymous subs are stored here with a name of "&",
         * so also check that the name is longer than one char.
         * (Note that the prefix letter is here as well, so a
         * valid variable will _always_ be >1 char)

		 * We ignore 'our' variables, since you can always dig
		 * them out of the stash directly.
         */

        if (!(SvFLAGS(name_sv) & SVpad_OUR) &&
		    (SvFAKE(name_sv) || 0 == valid_at_seq ||
            (valid_at_seq <= SvIVX(name_sv) &&
            valid_at_seq > I_32(SvNVX(name_sv)))) &&
            strlen(name_str) > 1 )

          {
            SV **val_ptr, *val_sv;

            val_ptr = av_fetch(pad_vallist, i, 0);
            val_sv = val_ptr ? *val_ptr : &PL_sv_undef;
			
	        hv_store(hash, name_str, strlen(name_str),
                     newRV_inc(val_sv), 0);
          }
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
context_vars(PERL_CONTEXT *cx, HV* ret, U32 seq, CV *cv)
{
    /* If cx is null, we take that to mean that we should look
     * at the cv instead
     */

	debug_print(("**context_vars(%p, %p, 0x%lx)\n",
			(void*)cx, (void*)ret, (long)seq));
    if (cx == (PERL_CONTEXT*)-1)
        croak("Not nested deeply enough");

    else {
        CV* cur_cv = cx ? cx->blk_sub.cv           : cv;
        U16 depth  = cx ? cx->blk_sub.olddepth + 1 : 1;

        if (!cur_cv)
            die("panic: Context has no CV!\n");
    
        while (cur_cv) {
            debug_print(("\tcv name = %s; depth=%d\n",
                    CvGV(cur_cv) ? GvNAME(CvGV(cur_cv)) :"(null)", depth));
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
    COP *cop = 0;
    I32 cxix_from, cxix_to, i;
	bool first_eval = TRUE;

  PPCODE:
    show_cxstack();
    if (PL_curstackinfo->si_type != PERLSI_MAIN)
	  debug_print(("!! We're in a higher stack level\n"));

    cx = upcontext(aTHX_ uplevel, &cop, &ccstack, &cxix_from, &cxix_to);
    debug_print(("** cxix = (%d,%d)\n", cxix_from, cxix_to));
    if (cop == 0) {
	   debug_print(("**Setting cop to PL_curcop\n"));
	   cop = PL_curcop;
	}
	debug_print(("**Cop file = %s\n", CopFILE(cop)));

    context_vars(cx, ret, cop->cop_seq, PL_main_cv);

    for (i = cxix_from-1; i > cxix_to; --i) {
        debug_print(("** CxTYPE = %s (cxix = %d)\n",
            cxtype_name(CxTYPE(&ccstack[i])), i));
        switch (CxTYPE(&ccstack[i])) {
        case CXt_EVAL:
            switch(ccstack[i].blk_eval.old_op_type) {
            case OP_ENTEREVAL:
	        if (first_eval) {
#if HAS_EVAL_CV
                   context_vars(0, ret, cop->cop_seq, ccstack[i].blk_eval.cv);
#else
                   /* This is wrong, but it's marginally better than
                    * nothing. It's essentially what older (<0.10)
                    * versions of PadWalker used to do. */
                   context_vars(0, ret, cop->cop_seq, PL_compcv);
#endif
                   first_eval = FALSE;
                }
#if HAS_EVAL_CV
               	context_vars(0, ret, ccstack[i].blk_oldcop->cop_seq,
						ccstack[i].blk_eval.cv);
#endif
		break;
            case OP_REQUIRE:
#if HAS_EVAL_CV
	        if (first_eval)
                   context_vars(0, ret, cop->cop_seq, ccstack[i].blk_eval.cv);
#endif
                goto END;
                /* If it's OP_ENTERTRY, we skip this altogether. */
            }
            break;

        case CXt_SUB:
#ifdef CXt_FORMAT
        case CXt_FORMAT:
#endif
		    Perl_die(aTHX_ "PadWalker: internal error");
			exit(EXIT_FAILURE);
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
    /* I'm not sure why this is here, but I'll leave it in case
	 * somebody is using it in an insanely evil way. */
    XPUSHs(sv_2mortal(newSViv((U32)upcontext(aTHX_ uplevel, 0, 0, 0, 0))));
