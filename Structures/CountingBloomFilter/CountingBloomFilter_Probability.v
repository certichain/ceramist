From mathcomp.ssreflect Require Import
     ssreflect ssrbool ssrnat eqtype fintype
     choice ssrfun seq path bigop finfun binomial.

From mathcomp.ssreflect Require Import tuple.

From mathcomp Require Import path.

From infotheo Require Import
     ssrR Reals_ext logb ssr_ext ssralg_ext bigop_ext Rbigop proba.

Require Import Coq.Logic.ProofIrrelevance.
Require Import Coq.Logic.FunctionalExtensionality.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

From ProbHash.Computation
     Require Import Comp Notationv1.

From ProbHash.Core
     Require Import Hash HashVec FixedList FixedMap.

From ProbHash.BloomFilter
     Require Import BloomFilter_Probability BloomFilter_Definitions.

From ProbHash.CountingBloomFilter
     Require Import CountingBloomFilter_Definitions.

From ProbHash.Utils
     Require Import InvMisc  seq_ext seq_subset rsum_ext stirling tactics.

Module CountingBloomFilter (Spec: HashSpec).


  Module CountingBloomFilterDefinitions := (CountingBloomFilterDefinitions Spec).
  Export CountingBloomFilterDefinitions.


  Section CountingBloomFilter.
    (*
    k - number of hashes
     *)
    Variable k: nat.
    (*
    n - maximum capacity of each counter
     *)
    Variable n: nat.

    Variable Hkgt0: k > 0.
    Variable Hngt0: n > 0.
    
    Lemma countingbloomfilter_preserve hashes l m (vals: seq B) hsh bf:
      l.+1 * k + m < n.+1 ->
      length vals == l ->
      ((d[ @countingbloomfilter_add_multiple k n hashes (countingbloomfilter_new n) vals])
         (hsh, bf) != 0) ->
      countingbloomfilter_free_capacity bf (k + m).
    Proof.
      elim: vals l m hsh bf  => [| val vals IHvals] [|l] m hsh bf Hltn Hlen //=.
      - {
          comp_normalize =>/bool_neq0_true; rewrite xpair_eqE =>/andP[_ /eqP ->].
          apply countingbloomfilter_new_capacity.
            by move: Hltn; rewrite mul1n.
        }
      - {
          comp_normalize; comp_simplify; comp_possible_decompose.
          move=> hsh' bf' hsh2 H1 H2 /bool_neq0_true/eqP ->.
          have H3: (length vals) == l; first by move/eqP: Hlen => //= [->].
          have H4: (l.+1 * k + (m + k) < n.+1); first by move: Hltn; rewrite mulSnr -addnA [k + m]addnC.
          move: (IHvals l (m + k) hsh' bf' H4 H3 H1) => Hpref; clear IHvals H4 H3 H1.
          eapply  countingbloomfilter_add_capacity_change.
          - by rewrite -length_sizeP size_tuple.
              by rewrite [k + m]addnC.
        }
    Qed.

    
    Theorem countingbloomfilter_counter_prob
            hashes l (values: seq B):
      l * k < n.+1 ->
      length values == l ->
      d[ 
          res1 <-$ @countingbloomfilter_add_multiple k n hashes (countingbloomfilter_new n) values;
            let (hashes1, bf') := res1 in
            ret (countingbloomfilter_bitcount bf' == l * k)
        ] true = 1.
    Proof.
      rewrite //= FDistBind.dE rsum_split //=.
      under eq_bigr => a _ do under eq_bigr => b _ do rewrite FDist1.dE eq_sym eqb_id.
      elim: values l => [| val vals  IHval] [|l] Hltn Hval //=.
      - {
            by comp_normalize; comp_simplify; rewrite countingbloomfilter_new_empty_bitcount.
        }
      - {
          comp_normalize.
          comp_simplify_n 2.
          erewrite <- (IHval l) => //=.
          apply eq_bigr=> hsh1 _; apply eq_bigr=> bf1 _.
          under eq_bigr => hsh2 _ do  under eq_bigr => bf2 _ do rewrite  mulRC -mulRA.
          under eq_bigr => hsh2 _ do rewrite -rsum_Rmul_distr_l.
          rewrite -rsum_Rmul_distr_l.
          case Hzr0: ((d[ countingbloomfilter_add_multiple hashes (countingbloomfilter_new n) vals]) (hsh1, bf1) == 0).
          - by move/eqP: Hzr0 ->; rewrite !mul0R.
          - {
              apply f_equal.
              under eq_bigr => a _; first under eq_bigr => a0 _.
              rewrite -(@countingbloomfilter_add_internal_incr _ k); first by over.
              - by rewrite -length_sizeP size_tuple eq_refl.
              - {
                  move/Bool.negb_true_iff: Hzr0 => Hzr0.
                  have H2: (length vals) == l; first by move/eqP: Hval => //= [->].
                  move: (@countingbloomfilter_preserve hashes l 0 vals hsh1 bf1 ).
                    by rewrite !addn0=> H1; move: (H1 Hltn H2 Hzr0).
                }
                  by over.
              - {
                  under_all ltac:(rewrite mulRC);
                  under eq_bigr => ? _ do rewrite -rsum_Rmul_distr_l; rewrite -rsum_Rmul_distr_l.
                  move: (fdist_is_fdist (d[ hash_vec_int val hsh1])) => [_ ]; rewrite rsum_split //= => ->.
                  rewrite mulR1; apply f_equal =>//=.
                    by rewrite mulSnr eqn_add2r.
                }
            }
          - by move: Hltn; rewrite mulSnr =>/addr_ltn.
        }
    Qed.


    Lemma countingbloomfilter_add_multiple_bloomfilter_eq cbf hashes values f:
      \sum_(a in [finType of (k.-tuple (HashState n) * CountingBloomFilter n)]%type)
       ((d[ countingbloomfilter_add_multiple hashes cbf values]) a *R*
        (f a.1 (toBloomFilter a.2))) =
      \sum_(a in [finType of (k.-tuple (HashState n) * BloomFilter)]%type)
       ((d[ bloomfilter_add_multiple hashes (toBloomFilter cbf) values]) a *R*
        (f a.1 a.2)).
    Proof.
      rewrite !rsum_split.
      under eq_bigr => hshs' _ do
                             rewrite (partition_big (toBloomFilter (n:=n)) predT) => //=.
      under eq_bigr => hshs' _ do
                             under eq_bigr => bf _ do
                                                 under eq_bigr => i /eqP Hbi do rewrite Hbi mulRC.
      rewrite exchange_big //= [\sum_(a in tuple_finType k _) _]exchange_big; apply eq_bigr => bf _.
      elim: values  bf f => [|val values IHval] bf f //=.
      - {
          apply eq_bigr => hshs' _.
          rewrite rsum_pred_demote; under eq_bigr => ? ? do rewrite FDist1.dE xpair_eqE mulRC [_ *R* (_ && _ %R)]mulRC andbC boolR_distr -!mulRA.
          rewrite -rsum_pred_demote big_pred1_eq FDist1.dE xpair_eqE boolR_distr.
          rewrite -mulRA; apply f_equal.
          rewrite [_ *R* f _ _ ]mulRC; apply f_equal.
            by apply f_equal; rewrite eqseqE eq_sym.
        }
      - {
          apply Logic.eq_sym.
          under eq_bigr => hshs' _.
          {
            rewrite FDistBind.dE.
            rewrite rsum_split //=.

            rewrite exchange_big.
            under eq_bigr =>  bf' _ do rewrite -(@IHval bf' (fun i bf' => FDistBind.d _ _ _ )).
            under eq_bigr =>  bf' _.

            rewrite exchange_big //=.
              by over.
                by over.
          }
          move=> //=; clear IHval.
          apply eq_bigr => hshs' _.
          apply Logic.eq_sym; under eq_bigr => ? ? do rewrite mulRC.
          rewrite -big_distrl //= mulRC.
          rewrite [_ *R* f _ _]mulRC; apply f_equal.
          under eq_bigr => ? ? do rewrite FDistBind.dE; rewrite exchange_big //= rsum_split //=.
          apply Logic.eq_sym.
          under eq_bigr => bf' _ do (rewrite rsum_pred_demote;under eq_bigr => ? ? do  rewrite rsum_Rmul_distr_l).
          exchange_big_outwards 1 => //=.
          exchange_big_outwards 2 => //=.
          apply eq_bigr => inds' _; apply eq_bigr => cbf' _.
          under eq_bigr do rewrite mulRC [_ *R* (d[ _ ]) _]mulRC -mulRA.
          rewrite -rsum_Rmul_distr_l; apply Logic.eq_sym.
          under eq_bigr do rewrite mulRC.
          rewrite -big_distrl  //= mulRC ; apply f_equal.
          under eq_bigr do rewrite FDistBind.dE; rewrite exchange_big //=; apply Logic.eq_sym.
          under eq_bigr do rewrite FDistBind.dE big_distrl //=; rewrite exchange_big; apply eq_bigr => [[hshs'' inds'']] _.
          under eq_bigr do rewrite [(d[ _ ]) _ *R* _ ]mulRC mulRC mulRA //=; rewrite -big_distrl //= mulRC; apply Logic.eq_sym.
          under eq_bigr do rewrite [(d[ _ ]) _ *R* _ ]mulRC  ; rewrite -big_distrl //= mulRC; apply f_equal.
          under eq_bigr do rewrite FDist1.dE xpair_eqE andbC boolR_distr//=; rewrite -big_distrl //= mulRC.
          apply Logic.eq_sym.
          under eq_bigr do rewrite FDist1.dE xpair_eqE andbC boolR_distr//= mulRA;
            rewrite -big_distrl //= mulRC; apply f_equal.
          apply Logic.eq_sym.
          rewrite rsum_pred_demote; under eq_bigr do rewrite mulRC; rewrite -rsum_pred_demote big_pred1_eq //=.
          rewrite -rsum_pred_demote (big_pred1 (toBloomFilter cbf')).
          rewrite -countingbloomfilter_bloomfilter_add_internalC //=.
          rewrite eqseqE //=; apply f_equal; case: bf => //=; rewrite /BitVector/toBloomFilter => bf //=.
          rewrite eq_sym inj_eq //=.
            by rewrite /injective //=;  intros x y hLxLy; injection hLxLy.
              by clear; move=> bf //=; rewrite eq_sym //=.
        }
    Qed.
    
    
    Theorem countingbloomfilter_collision_prob
            hashes l value (values: seq B):
      length values == l ->
      hashes_have_free_spaces hashes (l.+1) ->
      all (hashes_value_unseen hashes) (value::values) ->
      uniq (value::values) ->
      d[
          res1 <-$ countingbloomfilter_query value hashes (countingbloomfilter_new n);
            let (hashes1, init_query_res) := res1 in
            res2 <-$ @countingbloomfilter_add_multiple k n hashes1 (countingbloomfilter_new n) values;
              let (hashes2, bf) := res2 in
              res' <-$ countingbloomfilter_query value hashes2 bf;
                ret (res'.2)
        ] true =
      ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l.+1 * k) *R*
       \sum_(a in ordinal_finType (Hash_size.+2))
        (((((a %R) ^R^ k) *R* (Factorial.fact a %R)) *R* ('C(Hash_size.+1, a) %R)) *R* stirling_no_2 (l * k) a)).
    Proof.
      (* simplify proof a bit *)
      move=> Hlen Hfree Hall Huniq.

      comp_normalize; comp_simplify_n 2.
      exchange_big_outwards 5 => //=; comp_simplify_n 1.
      exchange_big_outwards 4 => //=; comp_simplify_n 1.
      under_all ltac:(rewrite countingbloomfilter_bloomfilter_query_eq).
      do 3!(exchange_big_outwards 5 => //=); move: (Hall) => //=/andP[];rewrite/hashes_value_unseen/hash_unseen => H1 _.
      under eq_bigr => ? ? do under eq_bigr => ? ? do under eq_bigr => ? ? do under eq_bigr => ? ? do under eq_bigr
      => ? ? do rewrite hash_vec_simpl //=.

      under_all ltac:(rewrite mulRA [(_ ^R^ _) *R* _]mulRC -!mulRA).

      under eq_bigr => inds _. {
        under eq_bigr => hshs _; first under eq_bigr => ins' _.

        move: (@countingbloomfilter_add_multiple_bloomfilter_eq
                 (countingbloomfilter_new n)
                 (Tuple (hash_vec_insert_length value hashes inds))
                 values
                 (fun i i0 =>
                    ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ k) *R*
                     ((d[ hash_vec_int value i]) (hshs, ins') *R*
                      ((true == bloomfilter_query_internal ins' i0) %R)))
                 )
              ); rewrite rsum_split //= => ->.
          by over. by over. by over. 
      }
      move=> //=.
      apply Logic.eq_sym; rewrite -rsum_Rmul_distr_l -(@bloomfilter_collision_prob k n hashes l value values Hlen Hfree Hall Huniq ).
      comp_normalize; comp_simplify_n 2.
      exchange_big_outwards 5 => //=; comp_simplify_n 1.
      exchange_big_outwards 4 => //=; comp_simplify_n 1.
      do 3!(exchange_big_outwards 5 => //=); move: (Hall) => //=/andP[];rewrite/hashes_value_unseen/hash_unseen => H2 _.
      under eq_bigr => ? ? do under eq_bigr => ? ? do under eq_bigr => ? ? do under eq_bigr => ? ? do under eq_bigr
      => ? ? do rewrite hash_vec_simpl //=.
      apply eq_bigr => inds _.
      apply eq_bigr => hshs _.
      apply eq_bigr => inds' _.
      rewrite rsum_split //=.
      apply eq_bigr => hshs'' _.
      apply eq_bigr => bf' _.
      apply Logic.eq_sym; rewrite mulRC -!mulRA; apply f_equal.
      apply Logic.eq_sym; rewrite mulRC -!mulRA; apply f_equal; apply f_equal.
        by rewrite counting_bloomfilter_new_bloomfilter_eq.
    Qed.
    


  End CountingBloomFilter.    
End CountingBloomFilter.