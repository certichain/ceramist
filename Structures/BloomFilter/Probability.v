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

From ProbHash.BloomFilter
     Require Import Definitions.

From ProbHash.Computation
     Require Import Comp Notationv1.

From ProbHash.Core
     Require Import Hash HashVec  FixedList  FixedMap.

From ProbHash.Utils
     Require Import InvMisc seq_ext seq_subset rsum_ext stirling tactics.
(*
Proof idea
----------
1. if hashstate_find value hash_state is None, then the output of the hash function is uniformly distributed from 0..Hash_size.+1
2. folding on a list of values such that all the values are not-equal ensures that hashstate_find value is always None
3. after insert, probability of all hash functions not setting a bit is (1 - 1/(Hash_size.+1))^k.
4. after k inserts,  probability of all hash functions not setting a bit is (1 - 1/(Hash_size.+1))^kn.
5. after k inserts,  probability of all hash functions setting a bit is 1 - (1 - 1/(Hash_size.+1))^kn.
 *)
Open Scope R_scope.

Lemma bool_neq0_true (v:bool) :
  (v %R) != BinNums.Z0 -> v = true.
Proof. by case: v => //=; move=> /eqP //=. Qed.



Lemma bloomfilter_second_stirling_number_sum: forall l k m (f: nat -> Rdefinitions.R),
    (\sum_(inds in [finType of (l * k).-tuple 'I_m.+1])
      ((Rdefinitions.Rinv (m.+1 %R) ^R^ l * k) *R*
       (f (length (undup inds)))) ) =
    \sum_(len in [finType of 'I_(m.+2)])
     (f(len) *R*
      ( ('C ((m.+1), len) %R) *R*
        (Factorial.fact len %R) *R* (stirling_no_2 (l * k) len) *R*
        (Rdefinitions.Rinv (m.+1 %R) ^R^ (l * k))
     )).
Proof.
  move=> l k m f.
  rewrite -rsum_Rmul_distr_l.
  under [\sum_(len in [finType of 'I_m.+2]) _]eq_bigr => inds Hinds do rewrite mulRA mulRC -!mulRA.  
  rewrite -rsum_Rmul_distr_l; apply f_equal.
  rewrite second_stirling_number_sum addn2.
  apply eq_bigr => ind Hind.
  by rewrite -mulRA; apply f_equal; rewrite mulRC.
Qed.


Section BloomFilter.
  (*
    k - number of hashes
   *)
  Variable k: nat.
  (*
    n - maximum number of hashes supported
   *)
  Variable n: nat.
  (* valid k *)
  Variable Hkgt0: k >0.

  (* the sequence of hash functions used to update the bloom filter *)
  Definition hash_vec := k.-tuple (HashState n).

  Lemma bloomfilter_add_internal_prob bf x l:
    ~~ tnth (bloomfilter_state bf) x ->
    \sum_(b in [finType of l.-tuple 'I_Hash_size.+1])
     ((tnth (bloomfilter_state (bloomfilter_add_internal b bf)) x %R) *R*
      ((Rdefinitions.Rinv (Hash_size.+1)%:R) ^R^ l)) = 
    (1 -R- ((1 -R- Rdefinitions.Rinv (Hash_size.+1)%:R) ^R^ l)).
  Proof.
    elim: l x bf=> [|l IHl] x bf Hnth //=.
    - {
        by rewrite rsum_empty mulR1 subRR;
             move/Bool.negb_true_iff: Hnth => //= ->; rewrite //= mul0R add0R.     
      }
    - {
        rewrite rsum_tuple_split rsum_split//=.
        rewrite (bigID (fun a => a == x)) big_pred1_eq //=.

        under eq_bigr => b _ do
        (rewrite bloomfilter_add_internal_preserve; first rewrite mul1R;
          last by rewrite /bloomfilter_set_bit/bloomfilter_state FixedList.tnth_set_nth_eq).            
        rewrite bigsum_card_constE//=.
        under eq_bigr => i Hneq do under eq_bigr => ? _ do rewrite mulRA mulRC mulRA mulRC.
        under eq_bigr => i Hneq do (rewrite -rsum_Rmul_distr_l; under eq_bigr => ? _ do rewrite mulRC).
        under eq_bigr => i Hneq do ( rewrite IHl; last by rewrite (FixedList.tnth_set_nth_neq) //=  eq_sym).
        rewrite bigsum_card_constE//= card_tuple  cardC1 card_ord //=.
        have->: (((Hash_size.+1 ^ l %R) *R*
                  (Rdefinitions.Rinv (Hash_size.+1 %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))) =
                 Rdefinitions.Rinv (Hash_size.+1 %R)
                ).
        {
          rewrite -{3}(mulR1 (Rdefinitions.Rinv _)) mulRA mulRC mulRA mulRC ; apply f_equal.
          rewrite -natRexp; clear; elim: l => [|l IHl] //=; rewrite ?mulR1//=.
          transitivity (
              (Rdefinitions.Rinv (Hash_size.+1 %R) *R* (Hash_size.+1 %R)) *R*
              (((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)) *R* (((Hash_size.+1 %R) ^R^ l)))
            ).
          {
            rewrite -mulRA -mulRA mulRC mulRA mulRC; apply f_equal.
            rewrite  mulRC mulRA mulRC; apply f_equal.
              by rewrite mulRC.                    
          }
          rewrite !Raxioms.Rinv_l ?mul1R ?IHl //=.
            by apply RIneq.not_0_INR =>//=.
        }
        rewrite !RIneq.Rmult_minus_distr_l addRA //= mulR1.
        rewrite -{1}(mul1R (Rdefinitions.Rinv _)) -RIneq.Rmult_plus_distr_r.
        have: (Rdefinitions.IZR 1 = (1 %R)); last move=>->; first by [].
        rewrite -natRD add1n RIneq.Rinv_r //= .
        rewrite addR_opp mulRA.
        have->: (((Hash_size %R) *R* Rdefinitions.Rinv (Hash_size.+1 %R))) =
        ((1 %R) -R- Rdefinitions.Rinv (Hash_size.+1 %R)).
        {
          rewrite -{2}(mulR1 (Rdefinitions.Rinv _)) //=.
          have: (1 %R) = Rdefinitions.IZR 1; last move=>->; first by [].
          rewrite -{1}(RIneq.Rinv_r (Hash_size.+1 %R)).
          rewrite [(_.+1 %R) *R* Rdefinitions.Rinv _]mulRC.
          rewrite -(RIneq.Rmult_minus_distr_l).
          have: (Rdefinitions.IZR 1 = (1 %R)); last move=>->; first by [].
            by rewrite -natRB //= subn1 //= mulRC.              
              by apply RIneq.not_0_INR =>//=.
        }
        have->: (1 %R) = Rdefinitions.IZR 1; by [].
          by apply RIneq.not_0_INR =>//=.        
      }
  Qed.


  Lemma bloomfilter_addn hashes (ind: 'I_(Hash_size.+1)) (bf: BloomFilter) (value: B):
    (* provided the bloom filter is not full *)
    @hashes_not_full k n  hashes ->
    (* and that the bloom filter has not set the value *)
    hashes_value_unseen hashes value ->
    (* the bit in question is not set  *)
    ~~ bloomfilter_get_bit ind bf ->
    P[
        (
          (* bf' is the result of inserting into bf *)
          res <-$ bloomfilter_add  value hashes bf;
            let: (new_hashes, bf') := res in
            (* the probability of the given bit being set is *)
            ret (~~ bloomfilter_get_bit ind bf')
        )
      ] = 
    ((1 -R- Rdefinitions.Rinv (Hash_size.+1)%:R) ^R^ k).
  Proof.
    rewrite /bloomfilter_add/hashes_not_full
            /hashes_value_unseen/hash_unseen
            /hash_not_full /bloomfilter_get_bit  => /allP Hnfl /allP Husn Hunset //= .  
    time comp_normalize.
    time comp_simplify.
    rewrite exchange_big //=.
    move: (Hpredkvld Hkgt0).
    move:  Hkgt0 hashes Hnfl Husn; rewrite /hash_vec.
    elim: k   => //=; clear k Hkgt0; case=> [ _  |k IHk] Hkgt0 hashes Hnfl Husn.
    {
      - move=> _ //=.
        rewrite mulR1.
        comp_normalize.
        comp_simplify.
        rewrite /hash/hashstate_find.
        have Hthead: (thead hashes) \in hashes; first by clear; rewrite (tuple_eta hashes) theadE//=; apply mem_head. 
        move/eqP: (Husn (thead hashes) Hthead) ->.
        rewrite exchange_big (bigID (fun values'' => values'' == ind)).
        have H x y z: y = (0 %R) -> x = z -> y +R+ x = z; first by move=> -> ->; rewrite add0R.
        apply H.
        {
          - apply prsumr_eq0P => ind' /eqP ->; first by dispatch_Rgt.
            move: (@bloomfilter_add_internal_hit bf ind (ind :: [::]) );
              rewrite/bloomfilter_state/bloomfilter_add_internal => //= ->.
            apply prsumr_eq0P => i' _; first by dispatch_Rgt.
              by rewrite mul0R.
                by apply mem_head.
        }
        transitivity ( 
          \sum_(i in 'I_Hash_size.+1 | i != ind)
           \sum_(i0 in hashstate_of_finType n)
           ((d[ rnd <-$ gen_random; ret (hashstate_put n value rnd (thead hashes), rnd)]) (i0, i))
        ).
        {
          - apply eq_bigr => ind' /andP [_ Hnind].
            apply eq_bigr => vl _.
            move: (@bloomfilter_add_internal_miss  bf ind (ind' :: [::])); rewrite /bloomfilter_state/bloomfilter_add_internal => //= ->.
              by rewrite eq_refl //= mul1R.
                by [].
                  by rewrite mem_seq1 eq_sym. 
        }
        comp_normalize.
        comp_simplify.
        apply prsumr_sans_one => //=.
          by rewrite card_ord.
          rewrite bigsum_card_constE card_ord RIneq.Rinv_r //=.
            by apply RIneq.not_0_INR => //=.
    }
    (* Base case completed *)           
    - {
        move=> Hpredkvld; rewrite -(IHk _ (FixedList.ntuple_tail hashes)); clear IHk; last first.
        { - by rewrite -pred_Sn. }
        {
          - destruct hashes eqn: Hhashes => ls.
            clear Hnfl; move: tval i Hhashes Husn => [//= | x [//=| y xs]] Hprf Heq Hnfl.
            rewrite FixedList.ntuple_tail_coerce => Hin; apply Hnfl => //=.
              by move: Hin; rewrite [ls \in [:: x, y & xs]]in_cons /tval => ->; rewrite Bool.orb_true_r.
        }
        {
          - destruct hashes eqn: Hhashes => ls.
            clear Husn; move: tval i Hhashes Hnfl => [//= | x [//= | y xs]] Hprf Heq Husn.
            rewrite FixedList.ntuple_tail_coerce => Hin; apply Husn => //=.
              by move: Hin; rewrite [ls \in [:: x, y & xs]]in_cons /tval => ->; rewrite Bool.orb_true_r.
        }
        { - by apply ltn0Sn. }
        {
          comp_normalize.
          comp_simplify_n 4.
          rewrite rsum_tuple_split rsum_split.
          exchange_big_outwards 5.
          apply eq_bigr => result _.
          exchange_big_outwards 3.
          apply eq_bigr => exp_hashes _.
          rewrite rsum_Rmul_distr_l rsum_tuple_split rsum_split.

          rewrite [\sum_(a in hashstate_of_finType n) \sum_(b in tuple_finType k _) _]exchange_big //=.
          exchange_big_outwards 2.
          apply eq_bigr => inds  _.
          apply Logic.eq_sym.
          comp_normalize.
          under_all ltac:(rewrite !cons_tuple_eq_tuple !xpair_eqE  !xcons_eqE !boolR_distr).
          comp_simplify.
          apply Logic.eq_sym.
          exchange_big_outwards 2.
          apply eq_bigr => ind'  _.
          under_all ltac:(rewrite  !mulRA mulRC).
          under eq_bigr => ? ? do under eq_bigr => ? ? do rewrite mulRC mulRA mulRC mulRA mulRC.
          under eq_bigr => ? ? do (under eq_bigr => ? ? do rewrite mulRC mulRA mulRC mulRA mulRC; rewrite -!rsum_Rmul_distr_l); rewrite -!rsum_Rmul_distr_l.
          apply Logic.eq_sym.
          rewrite mulRC; apply f_equal.
          rewrite mulRC; apply f_equal.
          apply Logic.eq_sym.
          have H:(thead hashes \in hashes); first by rewrite (tuple_eta hashes) in_cons theadE eq_refl //=.
          under_all ltac:(rewrite /hash/hashstate_find; move/eqP: (Husn _ H) => ->); clear H.
          comp_normalize.
          comp_simplify.

          rewrite (bigID (fun i => i == ind)) //=.      
          have H x y z: x = (0 %R) -> y = z -> x +R+ y = z; first by move=> -> -> //=; rewrite add0R.
          apply H.
          {
            - apply prsumr_eq0P => i /eqP ->; first by do?dispatch_eq0_obligations.
              rewrite eq_sym eqb_id.
              rewrite bloomfilter_add_internal_preserve; first by rewrite //= mul0R.
              rewrite bloomfilter_set_bitC.
                by move: (bloomfilter_set_get_eq ind (bloomfilter_set_bit result bf)); rewrite /bloomfilter_get_bit => ->.
          }
          rewrite eq_sym eqb_id; under eq_bigr => ? ? do rewrite eq_sym eqb_id.
          case Hind: (ind \in exp_hashes).              
          {
            - rewrite !bloomfilter_add_internal_hit //= mulR0.
              apply prsumr_eq0P => hshs' _; first by dispatch_Rgt; move=> [] //=.
                by rewrite bloomfilter_add_internal_hit //= mul0R.
          }
          case Hres: (result == ind).
          {
            move/eqP:Hres ->; rewrite bloomfilter_add_internal_preserve;
              last by move: (bloomfilter_set_get_eq ind bf); rewrite /bloomfilter_get_bit.
            rewrite //= mulR0.
            apply prsumr_eq0P => i Hineq;  first by do?dispatch_eq0_obligations.
            rewrite bloomfilter_add_internal_preserve; first (by rewrite //= mul0R);
              last by move: (bloomfilter_set_get_eq ind (bloomfilter_set_bit i bf)); rewrite /bloomfilter_get_bit.
          }
          rewrite bloomfilter_add_internal_miss; [
          | by move/Bool.negb_true_iff:
                 Hres => Hres; rewrite/bloomfilter_state/bloomfilter_set_bit tnth_set_nth_neq 1?eq_sym//=
          | by move/Bool.negb_true_iff:Hind]; rewrite mulR1.
          under eq_bigr => i Hi.
          {
            rewrite bloomfilter_add_internal_miss;
              by [ rewrite //= mul1R; over
                 | move/Bool.negb_true_iff:
                     Hres => Hres; rewrite/bloomfilter_state/bloomfilter_set_bit !tnth_set_nth_neq 1?eq_sym //=
                 |  move/Bool.negb_true_iff:Hind ].
          }
          apply prsumr_sans_one => //=.
            by rewrite card_ord.
            rewrite bigsum_card_constE card_ord RIneq.Rinv_r //=.
              by apply RIneq.not_0_INR => //=.
        }
      }
      (* DONE!!!! *)                                                         
  Qed.

  

  Lemma bloomfilter_add_multiple_unfold A hshs bf x xs (f: _ -> Comp A):
    d[ res <-$ @bloomfilter_add_multiple k n hshs bf (x :: xs);
         f (res) ] =
    d[
        res1 <-$ bloomfilter_add_multiple hshs bf xs;
          let (hshs', bf') := res1 in  
          res2 <-$ bloomfilter_add x hshs' bf';
            f (res2)
      ].
  Proof.
    apply fdist_ext => a //=.
    rewrite FDistBindA //=.
      by rewrite !FDistBind.dE; apply eq_bigr => [[hshs' bf']] _; apply f_equal => //=.
  Qed.
  

  Lemma bloomfilter_add_multiple_find_preserve value  inds hashes hashes' bf bf' xs:
    hash_vec_contains_value value hashes inds ->
    ((d[ @bloomfilter_add_multiple k n hashes bf xs]) (hashes', bf') != (0 %R)) ->
    hash_vec_contains_value value hashes' inds.
  Proof.
    move=> Hcontains.
    elim: xs hashes inds  Hcontains hashes' bf' => [//=| x xs IHxs] hashes inds Hcontains hashes' bf'.
    - {
        rewrite FDist1.dE xpair_eqE.
        case Hhashes: ((hashes') == _) => /eqP //= /eqP.
        case Hbf: ((bf') == _) => /eqP //= /eqP _.
          by move/eqP: Hhashes -> .
      }
    - {
        comp_normalize.
        comp_simplify.
        comp_possible_decompose.
        move=> hashes_internal' bf_prev inds' Heq0 Hhashes0 Hbf0.
        move: Heq0 => //= /IHxs Heq0. 
        move: (Heq0 _ Hcontains); clear Heq0 => Hcontains_internal.
            case Hneq: (value == x).
            - {
                move: Hcontains_internal Hhashes0.
                move/eqP: Hneq <- =>Hcontains_internal.
                erewrite hash_vec_find_simpl =>//=; last by exact Hcontains_internal.
                move=>/eqP; rewrite RIneq.INR_IZR_INZ; case Hand: (_ && _) => //= _.
                move/andP: Hand => [/eqP ->] //=.
              }
              move/Bool.negb_true_iff: Hneq => Hneq.
              move: Hneq Hcontains_internal Hhashes0; clear.
              move: k inds hashes' hashes_internal' inds';clear k; elim => [|k IHk].
            - {
                do 5!intro; rewrite !tuple0 //= FDist1.dE xpair_eqE => H3.  
                case Htrue: (_ && _); try rewrite RIneq.INR_IZR_INZ => /eqP //= _.
                  by move/andP: Htrue => [/eqP -> /eqP _].              
              }
            - {
                move=> [[//=| ind inds] Hinds] [[//=| hash hashes] Hhashes] [[//=| hash' hashes'] Hhashes'].
                move=> [[//=|ind' inds'] Hinds'] Hneq.
                comp_normalize.
                rewrite
                  (tuple_eta (Tuple Hhashes'))
                  (tuple_eta (Tuple Hinds))
                  (tuple_eta (Tuple Hhashes))
                  (tuple_eta (Tuple Hinds')) //=.
                rewrite !ntuple_tailE theadE//=.
                have->: ( thead (Tuple Hhashes)) = hash; first by [].
                have->: ( thead (Tuple Hhashes')) = hash'; first by [].
                have->: ( thead (Tuple Hinds)) = ind; first by [].
                have->: ( thead (Tuple Hinds')) = ind'; first by [].
                rewrite/hash_vec_contains_value //= => /andP[Hfind Hcontains].
                comp_possible_decompose.
                move=> b' b hsh_val ind_val Hint Hhash .
                rewrite !xpair_eqE !cons_tuple_eq_tuple !xcons_eqE.
                move=>/bool_neq0_true/andP [/andP [/eqP Hhsheq /eqP Htupleeq] /andP [/eqP Hindeq /eqP Hindstupleeq]].
                have Hcont':
                  hash_vec_contains_value value (behead_tuple (Tuple Hhashes')) (FixedList.ntuple_tail (Tuple Hinds));
                  first by rewrite/hash_vec_contains_value //=.
                move:
                  (IHk (FixedList.ntuple_tail (Tuple Hinds)) b' (behead_tuple (Tuple Hhashes')) b Hneq Hcont' Hint);
                  clear IHk; rewrite/hash_vec_contains_value //= -Htupleeq => ->; rewrite Bool.andb_true_r.
                move:  Hneq Hfind Hhash.
                rewrite Hhsheq /Hash.hash; clear.
                case: (hashstate_find n x hash') => //=.
                - {
                    move=> ind_val' Hneq; rewrite FDist1.dE xpair_eqE=> Hfind'/eqP.
                    case Hand: (_ && _) => //= _.
                      by move/andP: Hand => [/eqP ->] //=.
                  }
                - {
                    move=> Hneq Hfind //=; comp_normalize.
                    comp_possible_decompose.
                    move=> ind1 ind2 /bool_neq0_true; rewrite xpair_eqE=>/andP[/eqP-> /eqP <-] _/bool_neq0_true/eqP ->.
                    move: Hneq Hfind; clear.
                    move=> Hvalue.
                    move: n hash';clear n; elim => [//=|n IHn] [[//=| hash hashes] Hhashes].
                    rewrite (tuple_eta (Tuple Hhashes)) //=.
                    rewrite /FixedList.ntuple_head !theadE  !ntuple_tailE.
                    have->: (thead (Tuple Hhashes)) = hash; first by [].
                    case: hash Hhashes => [[k' v']|] Hhashes //=.
                    case Heq: (k' == value)=>//=.
                    - {
                        move/eqP: Heq ->.
                        move/Bool.negb_true_iff: Hvalue -> => //=.
                          by rewrite ntuple_head_consE eq_refl.                      
                      }
                    - {
                        move=> Hin; move: (Hin).
                        move=>/IHn Heq'.
                        case Hkeq: (k' == x) => //=.
                        - {
                            move/eqP:Hkeq <-; rewrite Heq //=; move: Hin.
                            rewrite/FixedList.ntuple_tail/behead_tuple.
                            move: (behead_tupleP _) => //= H1.
                            move: (behead_tupleP _) => //= H2.
                              by rewrite (proof_irrelevance _ H2 H1) //=.                          
                          }
                        - {
                              by rewrite ntuple_head_consE Heq ntuple_tail_consE.
                          }
                      }
                    - {
                        rewrite eq_sym in Hvalue; move/Bool.negb_true_iff: (Hvalue) -> => //=.
                        rewrite/FixedList.ntuple_tail/behead_tuple.
                        move: (behead_tupleP _) => //= H1.
                        move: (behead_tupleP _) => //= H2.
                          by rewrite (proof_irrelevance _ H2 H1) //=.                          
                      }
                  }
              }
          }
  Qed.            
  

  Lemma bloomfilter_add_multiple_preserve x xs l m hshs hshs' bf bf'
        (Huniq: uniq (x :: xs))
        (Hlen: length xs == l) 
        (Hfree: hashes_have_free_spaces hshs  ((l+m).+1))
        (Huns:      all (hashes_value_unseen hshs) (x :: xs)):
    ((d[ @bloomfilter_add_multiple k n hshs bf xs]) (hshs', bf') != (0 %R)) ->
    (hashes_have_free_spaces hshs' (m.+1)) && (hashes_value_unseen hshs' x).
  Proof.
    (* First clean up the proof *)
    move=> //=.
    rewrite -all_predI /predI //=.
    move: m hshs Hfree Huns bf bf' hshs'; rewrite/hash_vec.
    move/eqP: Hlen <-; clear l.
    have all_cons P y ys : all P (y :: ys) =  P y && all P ys. by [].
    move=> m hshs Hfree; rewrite all_cons => /andP []; move: x m hshs Huniq Hfree; clear all_cons.
    rewrite/hashes_have_free_spaces/hash_has_free_spaces/hashes_value_unseen/hash_unseen.
    (* proof has been cleaned up *)
    elim: xs => [//= | y ys IHy] x m hshs Huniq /allP Hfree /allP Huns Hx  bf bf' hshs'.
    - comp_normalize=>/bool_neq0_true; rewrite xpair_eqE =>/andP[/eqP -> _].
      apply /allP=> hsh Hin //=; apply/andP; split; by [apply Hfree | apply Huns].
    - move: Hx; have all_cons P z zs : all P (z :: zs) =  P z && all P zs. by [].
      rewrite all_cons => /andP [/allP Hfindy /allP Hfindys].
      have H1: uniq (x :: ys); first
        by move: Huniq => //=/andP [Hcons /andP [_ ->]]; move: Hcons; rewrite !in_cons Bool.negb_orb=>/andP[_ ->].
      have H2: all (fun hsh : HashState n => FixedList.fixlist_length hsh + (length ys + m.+1).+1 <= n) hshs;
        first by apply/allP => vec Hvec; move: (Hfree vec Hvec) => //=; rewrite addSn !addnS.
      have H3: all (fun hsh : HashState n => FixedMap.fixmap_find x hsh == None) hshs;
        first by apply /allP.
      have H4: all (fun b : B => all (fun hsh : HashState n => FixedMap.fixmap_find b hsh == None) hshs) ys;
        first by apply/allP.
      move: (IHy x m.+1 hshs H1 H2 H3 H4); clear IHy H1 H2 H3 H4 => IHy.

      comp_normalize.
      comp_possible_decompose => d_hshs' d_bf d_hshs'' d_ind /(IHy).
      clear IHy all_cons bf Hfree Huns Hkgt0 Hfindys .
      move=> Hall //= Hint /bool_neq0_true; rewrite xpair_eqE=>/andP[/eqP -> _].
      (* clear hshs'; elim: k hs1 hs2 vec1 Hint; clear hshs Hfindy k. *)
      clear hshs'; elim: k d_hshs' d_hshs'' d_ind Hint Hall; clear hshs Hfindy k.
    - by move=> hs1 hs2 vec1 //=; comp_normalize => /bool_neq0_true; rewrite xpair_eqE=>/andP[/eqP -> _] //=.
    - move=> k IHk hs1 hs2 vec1 //=; comp_normalize; comp_possible_decompose.
      move=> hs3 vec2 state1 ind1.
      move=>/IHk;clear IHk => IHk Hhash /bool_neq0_true; rewrite xpair_eqE => /andP[/eqP -> _ ] //= Hall.
      move: Hhash; rewrite/hash/hashstate_find.
      have Hthead: (thead hs1 \in hs1); first by rewrite (tuple_eta hs1) theadE in_cons eq_refl //=.
      case: (FixedMap.fixmap_find _ _) => [val //=|]. 
      - {
          comp_normalize => /bool_neq0_true; rewrite xpair_eqE => /andP[/eqP -> _]; apply/andP; split => //=.
          - by move/allP: Hall => /(_ _ Hthead) //=; rewrite !addnS => /andP [/ltnW -> ->] //=.
          -  apply IHk; apply/allP => v Hin; move/allP:Hall => Hall; apply/Hall.
             by move: Hin; rewrite (tuple_eta hs1) ntuple_tailE in_cons => ->; apply/orP; right.
      }
      - {
          comp_normalize; comp_possible_decompose
          => ind2 ind3 /bool_neq0_true;rewrite xpair_eqE=>/andP[/eqP -> Hind'] Hinv /bool_neq0_true/eqP ->.
          apply/andP;split;last first.
          - apply IHk; apply/allP => v Hv //=; move/allP:Hall => Hall; apply/Hall.
              by move: Hv; rewrite (tuple_eta hs1) ntuple_tailE in_cons => ->; apply/orP; right.
          - move/allP: Hall => /(_ _ Hthead) //= /andP[].
            rewrite !addnS -addSn addnC -ltn_subRL => Hlen Hfind; apply/andP;split.
            {
              rewrite addnC -ltn_subRL.
              apply (@leq_ltn_trans  (FixedList.fixlist_length (thead hs1)).+1) => //=.              
              clear Hlen IHk Hthead hs2 hs3 state1; move: (thead _) => [ls Hls]; clear hs1 Hfind.
              elim: n ls Hls => [//=|]; clear n => n IHn [//=|l ls] Hls //=.
              have->: (FixedList.ntuple_head (Tuple Hls)) = l; first by [].
              case: l Hls => [[k' v']|] Hls; last first; last case Heq: (_ == _).
              - by move: Hls (eq_ind _ _ _ _ _) => //=. 
              - by move: Hls (eq_ind _ _ _ _ _) => //= Hls Hls'. 
              - {
                  rewrite /FixedList.ntuple_tail; move: (behead_tupleP _) => //= Hls'.
                  move: (IHn ls Hls') => IHn'.
                  rewrite/FixedList.fixlist_length/FixedList.ntuple_cons.
                    by case Hput: (hashstate_put _) => [ms Hms] //=; move: IHn';rewrite Hput.
                }
            }
            {
              rewrite /hashstate_put.
              move: Huniq => //=/andP[];rewrite in_cons Bool.negb_orb=>/andP[Hneq _ _].
                by rewrite fixmap_find_neq //=. 
            }
        }
  Qed.
  
  

  Lemma bloomfilter_addn_Nuns  ind bf (hashes: hash_vec) x :
    bloomfilter_get_bit ind bf ->
    (d[ res <-$ bloomfilter_add x hashes bf;
          (let '(_, bf') := res in ret ~~ bloomfilter_get_bit ind bf')]) true = (0 %R).
  Proof.
    move=> Htnth //=.
    rewrite FDistBind.dE; apply prsumr_eq0P => a _ ; first by dispatch_Rgt.
    move: a => [hashes' bf'].
    rewrite FDistBind.dE rsum_Rmul_distr_r; apply prsumr_eq0P => a _; first by dispatch_Rgt.
    move: a => [hashes'' hvec] //=.
    rewrite !FDist1.dE xpair_eqE.
    case Hgth: (_ == _) => //=; rewrite ?mul1R; last by rewrite !mul0R.
    case Hhashes: (_ == _) => //=; rewrite ?Bool.andb_true_l; last by rewrite !mulR0.
    case Hbf: (_ == _) => //=; rewrite ?mulR1; last by rewrite mulR0.
    move/eqP: Hgth.
    move/eqP: Hbf ->.
    rewrite/bloomfilter_get_bit.
      by rewrite bloomfilter_add_internal_preserve //=.
  Qed.
  
  

  Lemma bloomfilter_addn_insert_multiple hashes l (ind: 'I_Hash_size.+1) (bf: BloomFilter) (values: seq B):
    length values == l ->
    hashes_have_free_spaces hashes l ->
    all (hashes_value_unseen hashes) values ->
    uniq values ->
    ~~ bloomfilter_get_bit ind bf ->
    (d[ res <-$ @bloomfilter_add_multiple  k n hashes bf values;
          (let '(_, bf') := res in ret ~~ bloomfilter_get_bit ind bf')]) true =
    ((1 -R- Rdefinitions.Rinv (Hash_size.+1 %R)) ^R^ (k * l)).
    elim: l ind bf values hashes => [|l IHl] ind bf values hashes0 .
    - case: values => //= _ _ _ _ Htnth; rewrite muln0 //= FDistBind.dE rsum_split //=.
      transitivity (
          \sum_(a in [finType of k.-tuple (HashState n)])
           \sum_(b in [finType of BloomFilter])
           (((a == hashes0) &&  (b == bf) %R) *R* (FDist1.d (~~ bloomfilter_get_bit ind b)) true)
        ).
        by apply eq_bigr => a _; apply eq_bigr => b _; rewrite !FDist1.dE //= xpair_eqE.
        transitivity ((true == (~~ bloomfilter_get_bit ind bf) %R)).   
        rewrite (bigID (fun a => a == hashes0)) //= big_pred1_eq.
        have H x y z: y = (0 %R) -> x = z -> x +R+ y = z. by move=> -> ->; rewrite addR0.
        apply H.
    - apply prsumr_eq0P => i /Bool.negb_true_iff -> //=; first by dispatch_Rgt.
      apply prsumr_eq0P => b _; first by dispatch_Rgt.
        by rewrite mul0R.
        rewrite (bigID (fun b => b == bf)) //= big_pred1_eq.
        apply H.
    - apply prsumr_eq0P => i /Bool.negb_true_iff -> //=; first by dispatch_Rgt.
        by rewrite Bool.andb_false_r //= mul0R.
          by rewrite !eq_refl //= mul1R FDist1.dE.
            by rewrite Htnth.
    - rewrite mulnS.
      case: values => [//= | x xs] Hlen Hfree Huns Huniq Hnb.
      rewrite bloomfilter_add_multiple_unfold.
      rewrite RealField.Rdef_pow_add.
      erewrite <- (IHl ind bf xs hashes0) => //=.
      rewrite mulRC //= !FDistBind.dE rsum_Rmul_distr_r; apply eq_bigr => [[hshs' bf']] _.
      case Hnz: (d[ bloomfilter_add_multiple hashes0 bf xs ] (hshs', bf') == (0 %R));
        first by move/eqP: Hnz ->; rewrite !mul0R mulR0.
      move/Bool.negb_true_iff: Hnz => Hnz.
      move: Hfree; rewrite -(addn0 l) => Hfree.
      move: (bloomfilter_add_multiple_preserve Huniq Hlen Hfree Huns Hnz) => /andP [].
      rewrite /hashes_have_free_spaces/hashes_value_unseen => Hfree' Huns'.
      apply Logic.eq_sym; rewrite mulRA mulRC mulRA mulRC; apply f_equal; apply Logic.eq_sym.
      case Htnth': (~~ bloomfilter_get_bit ind bf').
    - have <-: (Rdefinitions.IZR 1) = (BinNums.Zpos BinNums.xH); first by [].
      erewrite <-  (@bloomfilter_addn hshs' ind bf' x) => //=.
    - by rewrite FDist1.dE //= mul1R !FDistBind.dE //=; apply eq_bigr => [[hshs'' bf'']] _.
    - move: Hfree'; rewrite /hashes_not_full/hash_has_free_spaces => /allP Hlt; apply/allP => cell Hcell; rewrite /hash_not_full.
        by move: (Hlt cell Hcell); rewrite addn1 //=.
    - move /Bool.negb_false_iff: Htnth' => Htnth'; rewrite FDist1.dE // mul0R.
        by rewrite bloomfilter_addn_Nuns //=.
        move/allP: Hfree => Hfree; apply/allP => cell Hcell.        
        move: (Hfree cell Hcell); rewrite /hash_has_free_spaces.
          by rewrite addnS => /ltnW.
          move /allP: Huns => Huns; apply/allP => x' Hx'.
          apply Huns => //=.
            by rewrite in_cons Hx' Bool.orb_true_r.
              by move: Huniq => //= /andP [].
  Qed.
  
  (* TODO: No False Negatives *)


  

  Lemma bloomfilter_add_internal_indep l bf' x xs :
    tnth (bloomfilter_state bf') x ->
    uniq (x :: xs) ->
    length (x::xs) < Hash_size.+1 ->
    \sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
     (((tnth (bloomfilter_state (bloomfilter_add_internal inds bf')) x &&
             all [eta tnth (bloomfilter_state (bloomfilter_add_internal inds bf'))] xs) %R) *R*
      (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)) =
    ((\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
       (((tnth (bloomfilter_state (bloomfilter_add_internal inds bf')) x) %R) *R*
        (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))) *R*
     (\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
       ((( all [eta tnth (bloomfilter_state (bloomfilter_add_internal inds bf'))] xs) %R) *R*
        (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))).
  Proof.
    have H x1 y1 z1: y1 = (0 %R) -> x1 = z1 -> x1 +R+ y1 = z1. by move=> -> ->; rewrite addR0.
    elim: l bf' x xs=> [//=|l IHl] bf' x xs.
    -  move=> Htnth /andP[Hnin Huniq] Hlen; rewrite unlock=>//=.
       have: (index_enum [finType of 0.-tuple 'I_Hash_size.+1]) = [tuple]::[::].
       rewrite /index_enum/[finType of _]//= /prod_finMixin/prod_countMixin //=.
       rewrite -enumT //=; rewrite/(enum _)//=.
       rewrite {1}Finite.EnumDef.enumDef/prod_enum //=.
       move: (FinTuple.size_enum 0 (ordinal_finType Hash_size.+1))=> //=; rewrite expn0.
       move: (FinTuple.enum _ _)=>[|[[|//=] Hz] []]//= _.
         by move: (@tuple0  'I_Hash_size.+1 (Tuple Hz)) <- =>//=.
         move=> -> //=.
         rewrite !addR0.
           by case: (tnth _ _) => //=;rewrite?mul1R?mul0R//=;case: (all _ _)=>//=;rewrite?mul1R.
    - move=> Htnth Huniq Hlength.
      rewrite rsum_tuple_split rsum_split=>//=.
      transitivity (
          \sum_(a in 'I_Hash_size.+1)
           (Rdefinitions.Rinv (Hash_size.+1 %R) *R*
            \sum_(b in [finType of l.-tuple 'I_Hash_size.+1])
             ((tnth (bloomfilter_state
                       (bloomfilter_add_internal b (bloomfilter_set_bit a bf'))) x &&
                    all [eta tnth (bloomfilter_state
                                     (bloomfilter_add_internal b (bloomfilter_set_bit a bf')))]
                    xs %R) *R*
              ( (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))
        ).
      apply eq_bigr => a _; rewrite rsum_Rmul_distr_l; apply eq_bigr => b _.
      rewrite mulRA mulRC mulRA mulRC; apply f_equal.
        by rewrite mulRC; apply f_equal.
        transitivity (
            \sum_(a in 'I_Hash_size.+1)
             (Rdefinitions.Rinv (Hash_size.+1 %R) *R*
              (\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                ((tnth (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf'))) x %R) *R*
                 (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)) *R*
               \sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                ((all [eta tnth (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))]
                      xs %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))
             )
          ).
        apply eq_bigr=> a _; apply f_equal.
        rewrite IHl; last first; try by [].
        case Haeq: (x == a); first by
            rewrite /bloomfilter_set_bit/bloomfilter_state FixedList.tnth_set_nth_eq //=.
          by rewrite FixedList.tnth_set_nth_neq //=;  move/Bool.negb_true_iff: Haeq.
          have: (\sum_(inds in [finType of (l.+1).-tuple 'I_Hash_size.+1])
                  ((tnth (bloomfilter_state
                            (bloomfilter_add_internal inds bf')) x %R) *R*
                   (Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                    (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))) =
                 \sum_(inds in [finType of (l.+1).-tuple 'I_Hash_size.+1])
                  (Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                   (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))
                ).
          apply eq_bigr=> inds _.
          rewrite -{2}(mulR1 (Rdefinitions.Rinv _ *R* _)).
          rewrite mulRC; apply f_equal.
            by rewrite bloomfilter_add_internal_preserve //=.
            move=> ->; rewrite bigsum_card_constE.
            
            transitivity (
                Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                \sum_(a in 'I_Hash_size.+1)
                 ((\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                    ((tnth (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf'))) x %R) *R*
                     (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)) *R*
                   \sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                    ((all
                        [eta tnth
                             (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))]
                        xs %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))                 
              ).
            rewrite rsum_Rmul_distr_l.
              by apply eq_bigr=> a _.
              transitivity (
                  Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                  \sum_(a in 'I_Hash_size.+1)
                   ((\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                      ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))   *R*
                     \sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                      ((all
                          [eta tnth
                               (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))]
                          xs %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))                 
                ).
              apply f_equal; apply eq_bigr=> a _.
              rewrite mulRC; apply Logic.eq_sym; rewrite mulRC; apply f_equal; apply Logic.eq_sym.
              apply eq_bigr=> inds _.
              rewrite bloomfilter_add_internal_preserve.
                by rewrite mul1R.
                rewrite/bloomfilter_state/bloomfilter_set_bit.
                case Haeq:(x == a); first by rewrite FixedList.tnth_set_nth_eq //=.
                  by move/Bool.negb_true_iff: Haeq=>Haeq; rewrite FixedList.tnth_set_nth_neq//=.
                  transitivity (
                      Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                      \sum_(a in 'I_Hash_size.+1)
                       ((((#|[finType of l.-tuple 'I_Hash_size.+1]| %R) *R*
                          ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))   *R*
                         \sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                          ((all
                              [eta tnth
                                   (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))]
                              xs %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))                 
                    ).
                  apply f_equal; apply eq_bigr => a _.
                    by rewrite bigsum_card_constE //=.
                    transitivity (
                        Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                        ((#|[finType of l.-tuple 'I_Hash_size.+1]| %R) *R*
                         ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))   *R*
                        \sum_(a in 'I_Hash_size.+1)
                         ((\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                            ((all
                                [eta tnth
                                     (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))]
                                xs %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))                 
                      ).
                    rewrite !rsum_Rmul_distr_l; apply eq_bigr=> a _.
                      by rewrite mulRA; apply f_equal.
                      transitivity (
                          Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                          (((#|[finType of l.-tuple 'I_Hash_size.+1]| %R) *R*
                            ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))   *R*
                           \sum_(a in 'I_Hash_size.+1)
                            ((\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                               ((all
                                   [eta tnth
                                        (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))]
                                   xs %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))) 
                        )).
                        by rewrite -mulRA.
                        apply Logic.eq_sym.  
                        transitivity (
                            Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                            (((#|[finType of (l.+1).-tuple 'I_Hash_size.+1]| %R) *R*
                              (
                                (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))) *R*
                             \sum_(inds in [finType of (l.+1).-tuple 'I_Hash_size.+1])
                              ((all [eta tnth (bloomfilter_state (bloomfilter_add_internal inds bf'))] xs %R) *R*
                               (Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                                (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))
                          ).
                        rewrite -mulRA mulRC -mulRA -mulRA; apply f_equal. 
                        rewrite !rsum_Rmul_distr_l !rsum_Rmul_distr_r mulRC !rsum_Rmul_distr_r.
                        apply eq_bigr=> a _.
                        rewrite mulRC -mulRA -mulRA -mulRA -mulRA; apply f_equal.
                        rewrite mulRC -mulRA mulRC -mulRA  -mulRA; apply f_equal.
                          by rewrite mulRC -mulRA; apply f_equal.
                          apply f_equal.                 
                          transitivity (
                              ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)) *R*
                              (((#|[finType of (l.+1).-tuple 'I_Hash_size.+1]| %R)) *R*
                               \sum_(inds in [finType of (l.+1).-tuple 'I_Hash_size.+1])
                                ((all [eta tnth (bloomfilter_state (bloomfilter_add_internal inds bf'))] xs %R) *R*
                                 (Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                                  (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))
                            ).
                            by rewrite -mulRA mulRC -mulRA; apply f_equal; rewrite mulRC.
                            apply Logic.eq_sym.    
                            transitivity (
                                ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)) *R*
                                (((#|[finType of l.-tuple 'I_Hash_size.+1]| %R)) *R*
                                 \sum_(a in 'I_Hash_size.+1)
                                  ((\sum_(inds in [finType of l.-tuple 'I_Hash_size.+1])
                                     ((all
                                         [eta tnth
                                              (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))]
                                         xs %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))) 
                              )).
                              by rewrite -mulRA mulRC -mulRA; apply f_equal; rewrite mulRC.
                              apply f_equal; apply Logic.eq_sym.    
                              transitivity (
                                  Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                                  (((#|[finType of (l.+1).-tuple 'I_Hash_size.+1]| %R)) *R*
                                   \sum_(inds in [finType of (l.+1).-tuple 'I_Hash_size.+1])
                                    ((all [eta tnth (bloomfilter_state (bloomfilter_add_internal inds bf'))] xs %R) *R*
                                     ( (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))
                                ).
                              apply Logic.eq_sym; rewrite mulRA mulRC mulRA mulRC; apply f_equal.
                              rewrite rsum_Rmul_distr_r; apply eq_bigr=> inds _.
                                by rewrite mulRC -mulRA; apply f_equal; rewrite mulRC.
                                rewrite rsum_tuple_split rsum_split !rsum_Rmul_distr_l; apply eq_bigr=> a _.
                                rewrite !rsum_Rmul_distr_l; apply eq_bigr=> inds _ //=.
                                transitivity ((all [eta tnth (bloomfilter_state (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))] xs %R) *R*
                                              (Rdefinitions.Rinv (Hash_size.+1 %R) *R*
                                               ((#|[finType of (l.+1).-tuple 'I_Hash_size.+1]| %R) *R*
                                                ( (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l))))).
                                rewrite mulRC -mulRA mulRC -mulRA -mulRA; apply f_equal.
                                  by rewrite mulRC -mulRA; apply f_equal; rewrite mulRC.
                                  apply Logic.eq_sym.    
                                  transitivity (
                                      (all [eta tnth (bloomfilter_state
                                                        (bloomfilter_add_internal inds (bloomfilter_set_bit a bf')))] xs
                                           %R) *R* 
                                      ((#|[finType of l.-tuple 'I_Hash_size.+1]| %R) *R*
                                       ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))                 
                                    ).
                                    by rewrite mulRC -mulRA; apply f_equal; rewrite mulRC //=.
                                    apply f_equal.
                                    rewrite !card_tuple //=.
                                    rewrite expnSr card_ord natRM; apply Logic.eq_sym.
                                    transitivity (
                                        ((Rdefinitions.Rinv (Hash_size.+1 %R) *R* (Hash_size.+1 %R)) *R*
                                         (((Hash_size.+1 ^ l %R)) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l)))                           ).
                                      by rewrite -mulRA -mulRA; apply f_equal; rewrite mulRC -mulRA;
                                        apply f_equal; rewrite mulRC.
                                      rewrite Raxioms.Rinv_l; first by rewrite mul1R.
                                        by apply RIneq.not_0_INR =>//=.
  Qed.

  Lemma bloomfilter_addn_insert_multiple_inv hashes l (ind: 'I_Hash_size.+1) (bf: BloomFilter) (values: seq B):
    length values == l ->
    hashes_have_free_spaces hashes l ->
    all (hashes_value_unseen hashes) values ->
    uniq values ->
    ~~ bloomfilter_get_bit ind bf ->
    (d[ res <-$ @bloomfilter_add_multiple k n hashes bf values;
          (let '(_, bf') := res in ret bloomfilter_get_bit ind bf')]) true =
    (1 -R- ((1 -R- Rdefinitions.Rinv (Hash_size.+1 %R)) ^R^ (k * l))).
  Proof.
    move=> Hlen Hhashes Huns Huniq Hnth.
    transitivity (
        (d[ res <-$ bloomfilter_add_multiple hashes bf values;
            ret (fun res' => (let '(_, bf') := res' in bloomfilter_get_bit ind bf')) res]) true
      ).
    - by rewrite //= !FDistBind.dE; apply/eq_bigr=>[[hs' bf']] _ //=.
      rewrite -(prsumr_neg1 ).
      transitivity (
          (1 -R- (d[ res <-$ bloomfilter_add_multiple hashes bf values;
                     (let '(_, bf') := res in ret ~~ bloomfilter_get_bit ind bf')]) true)
        ).
    - by rewrite //= !FDistBind.dE; apply f_equal; apply/eq_bigr=>[[hs' bf']] _ //=.
        by rewrite (@bloomfilter_addn_insert_multiple _ l).       
  Qed.


  Lemma bloomfilter_hits_preserve (xs : seq B) (l : nat_eqType) (m : nat)
        (hshs : k.-tuple (HashState n)) (hshs' : tuple_finType k (hashstate_of_finType n))
        (bf bf' : bloomfilter_finType) inds :
   length xs == l ->
   all (bloomfilter_get_bit^~ bf) inds ->
   (d[ bloomfilter_add_multiple hshs bf xs]) (hshs', bf') != (0 %R) ->
   all (bloomfilter_get_bit^~ bf') inds.
  Proof.
    elim: l xs bf inds hshs' bf' => [//= [|//=]| l IHl [//=| x xs]] bf inds hshs' bf' Hlen Hall //=.
    - {
        rewrite FDist1.dE xpair_eqE =>/eqP; case Hand: (_ && _) => //= _.
        by move/andP: Hand => [_ /eqP ->] //=.
      }
    - {
        rewrite FDistBind.dE => /eqP/prsumr_ge0; case => [pr | [hsh1 bf1]]; first by dispatch_Rgt.

        move=>/RIneq.Rgt_not_eq/eqP; rewrite mulR_neq0' =>/andP [].
        have H1: length xs == l; first by move/eqP: Hlen => [->].
        move=>/(@IHl xs _ _ hsh1 bf1 H1  Hall) //= Hall'; rewrite FDistBind.dE.
        move => /eqP/prsumr_ge0; case => [pr | [hsh2 bf2]]; first by dispatch_Rgt.
        move=>/RIneq.Rgt_not_eq/eqP; rewrite mulR_neq0' =>/andP [ Hint //= ].
        rewrite FDist1.dE xpair_eqE =>/eqP; case Hand: (_ && _) => //= _.
        move/andP: Hand Hall' => [_ /eqP ->].

        move=>/allP Hget; apply/allP => ind Hind.
        apply bloomfilter_add_internal_preserve.
        move: (Hget ind Hind) => //=.
      }
  Qed.
  
  Theorem bloomfilter_no_false_negatives l  bf (hashes: hash_vec) x xs :
    uniq (x :: xs) ->
    length xs == l ->
    hashes_have_free_spaces hashes (l.+1) ->
    all (hashes_value_unseen hashes) (x::xs) ->
    (d[ res1 <-$ bloomfilter_add x hashes bf;
          let '(hsh1, bf1) := res1 in
          res2 <-$ bloomfilter_add_multiple hsh1 bf1 xs;
            let '(hsh2, bf2) := res2 in
            res3 <-$ bloomfilter_query x hsh2 bf2;
              ret (snd res3) ] true) = (1 %R).
  Proof.
    move=> Huniq Hlen Hfree Huns .
    rewrite//= FDistBind.dE //=; under eq_bigr => a _ do rewrite FDistBind.dE //=.
    under eq_bigr => a _ do rewrite rsum_split //=.
    under eq_bigr => ? _ do rewrite exchange_big.
    under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite FDist1.dE mulRC ?xpair_eqE.
    rewrite rsum_split //=.
    under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite  eq_sym xpair_eqE boolR_distr -!mulRA.
     under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _  do rewrite -rsum_pred_demote big_pred1_eq.
     under eq_bigr => ? _ do (under eq_bigr => ? _ do rewrite rsum_Rmul_distr_r).
     under eq_bigr => ? _ do rewrite exchange_big.
     under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite mulRC eq_sym -!mulRA.
     under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite -rsum_pred_demote big_pred1_eq.
     under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite mulRC FDistBind.dE.
     rewrite exchange_big;
       under eq_bigr => ? _ do (under eq_bigr => ? _ do rewrite rsum_Rmul_distr_r).
     under eq_bigr => ? _ do rewrite exchange_big.
     under eq_bigr => i Hi. under eq_bigr => j Hj. rewrite hash_vec_simpl //=; try
       by move: Huns => //=/andP[];rewrite/hashes_value_unseen/hash_unseen //=.
     by over. by over.
     move=> //=.
       under eq_bigr => ? _ do rewrite rsum_split //=.
       under eq_bigr => ? _ do (under eq_bigr => ? _  do rewrite -rsum_Rmul_distr_l).
       under eq_bigr => ? _ do rewrite -rsum_Rmul_distr_l.
       rewrite -rsum_Rmul_distr_l.
       under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite FDistBind.dE.
       under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do  under eq_bigr => ? _ do rewrite FDistBind.dE //=.
      under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite mulRC FDist1.dE eq_sym.
      under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite rsum_split//=.
      under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite -rsum_pred_demote big_pred1_eq.
      under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite rsum_split //=.
      under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do
            rewrite mulRC FDist1.dE eq_sym xpair_eqE eqb_id boolR_distr -!mulRA.
      under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do rewrite exchange_big.
      under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ do under eq_bigr => ? _ 
        do under eq_bigr => ? _ do rewrite -rsum_pred_demote big_pred1_eq.
      move: Huns => //=/andP [_ Huns].
      transitivity (
          ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ k) *R*
           \sum_(i in tuple_finType k (ordinal_finType Hash_size.+1))
            \sum_(i0 in tuple_finType k (hashstate_of_finType n))
            \sum_(i1 in bloomfilter_finType)
            ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length x hashes i))
                                          (bloomfilter_add_internal i bf) xs]) (i0, i1) *R*
             (bloomfilter_query_internal i i1 %R)
        ))).
    - {
        apply f_equal.
        apply eq_bigr => inds _.
        apply eq_bigr => inds' _.
        apply eq_bigr => bf' _.
        case Heq0: ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length x hashes inds))
                                                 (bloomfilter_add_internal inds bf) xs]) (inds', bf') == 0).
        - by move/eqP: Heq0 ->; rewrite //= ?mulR0 ?mul0R.
          move/Bool.negb_true_iff: Heq0 => Heq0.
          apply f_equal.
          move/bloomfilter_add_multiple_find_preserve: (Heq0) => /(_ x inds) Hfind.
          under eq_bigr => i _.  under eq_bigr => i0 _.
          rewrite (@hash_vec_find_simpl _ _ x _ _ inds _); last apply Hfind.
            by over.
            apply hash_vec_contains_value_base;apply/allP => //= h Hh.
            move/allP: Hfree; rewrite/hashes_have_free_spaces/hash_has_free_spaces => /(_ h Hh).
            have ->: [length h] + l.+1 = [length h].+1 + l; first by rewrite addnS -addSn.
              by rewrite addn1; move=>/leq_addr_weaken.
              by over.

          under eq_bigr => i _ do under eq_bigr => i0 _ do rewrite mulRC andbC boolR_distr -!mulRA.
          under eq_bigr => i _ do rewrite -rsum_pred_demote big_pred1_eq.
            by rewrite -rsum_pred_demote big_pred1_eq //=.

      }
      transitivity (
        ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ k) *R*
         \sum_(i in tuple_finType k (ordinal_finType Hash_size.+1))
          \sum_(i0 in tuple_finType k (hashstate_of_finType n))
          \sum_(i1 in bloomfilter_finType)
          ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length x hashes i))
                                        (bloomfilter_add_internal i bf) xs]) (i0, i1)
      ))).
      {
        rewrite /bloomfilter_query_internal.        
        apply f_equal; apply eq_bigr => inds _ ; apply eq_bigr=> hshs1 _; apply eq_bigr=> bf1 _.
        case Heq0: ((d[ bloomfilter_add_multiple
                          (Tuple (hash_vec_insert_length x hashes inds))
                          (bloomfilter_add_internal inds bf) xs]) (hshs1, bf1) == 0);
          first by move/eqP: Heq0 ->; rewrite //= ?mulR0 ?mul0R.
        move/Bool.negb_true_iff: Heq0 => Heq0.
        have Hset: (all (bloomfilter_get_bit^~ (bloomfilter_add_internal inds bf)) inds).
        {
          apply/allP => ind Hind.
            by apply bloomfilter_add_internal_hit.
        }
        move: (@bloomfilter_hits_preserve xs l 0 _ _ _ _  inds Hlen Hset Heq0) -> .
          by rewrite mulR1.
      }
      transitivity (
        ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ k) *R*
         \sum_(i in tuple_finType k (ordinal_finType Hash_size.+1)) (1 %R))
      ).
      {
        apply f_equal; apply eq_bigr=> i _.
        move: (fdist_is_fdist ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length x hashes i))
                                                            (bloomfilter_add_internal i bf) xs]))) => [_ ] //=.
          by rewrite rsum_split //= => ->.
      }
      rewrite bigsum_card_constE card_tuple card_ord mulR1 -natRexp -expRM mulRC mulRV ?exp1R//=.
        by rewrite RIneq.INR_IZR_INZ; apply/eqP => //=.
  Qed.
  

  Theorem bloomfilter_addn_bits
          hashes b (inds: seq 'I_Hash_size.+1) (bf: BloomFilter) (value: B):
    b < k ->
    length inds == b ->
    @hashes_have_free_spaces k n hashes 1 ->
    (hashes_value_unseen hashes value)  ->
    uniq inds ->
    all (fun ind => ~~ bloomfilter_get_bit ind bf) inds ->
    (d[ res <-$ bloomfilter_add value hashes bf;
          (let '(_, bf') := res in ret (all (bloomfilter_get_bit^~ bf') inds))]) true = 
    \sum_(i in tuple_finType k (ordinal_finType Hash_size.+1))
     ((((inds \subseteq i) == true) %R) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ k)).
  Proof.
    have H x1 y1 z1: y1 = (0 %R) -> x1 = z1 -> x1 +R+ y1 = z1; first by move=> -> ->; rewrite addR0.
    rewrite //= FDistBind.dE => Hb Hlen Hfree Huns Huniq Hall.
    under eq_bigr => a _ do rewrite FDistBind.dE //= !rsum_Rmul_distr_r //=.
    under eq_bigr => a _ do rewrite  ?rsum_Rmul_distr_r //=.
    rewrite rsum_split //=.
    under eq_bigr => a _ do under eq_bigr => b0 _  do rewrite FDist1.dE eq_sym.
    under eq_bigr => a _  do rewrite exchange_big.
    rewrite exchange_big rsum_split//=.
    under eq_bigr => a _ do under eq_bigr => b0 _ do under eq_bigr => i _ do under eq_bigr => i0 _ do rewrite FDist1.dE xpair_eqE.
    under eq_bigr => a _ do under eq_bigr => b0 _ do rewrite (bigID (fun i => i == a)) big_pred1_eq //=.
    under eq_bigr => a _ do rewrite addRA_rsum.
    rewrite addRA_rsum.
    erewrite H; last by []; last first.
    {
      do 2!(apply prsumr_eq0P; intros; first by intros; dispatch_Rgt).
      apply prsumr_eq0P => i /Bool.negb_true_iff ->; first by intros; dispatch_Rgt.
      apply prsumr_eq0P; intros; first by intros; dispatch_Rgt.
        by rewrite //= !mulR0.
    }
    under eq_bigr => i _  do under eq_bigr => i0 _  do rewrite (bigID (fun j => j == (bloomfilter_add_internal i0 bf))) big_pred1_eq //=.
    under eq_bigr => i _ do rewrite addRA_rsum //=.
    rewrite addRA_rsum.
    erewrite H; last by []; last first.
    {
      do 2!(apply prsumr_eq0P; intros; first by intros; dispatch_Rgt).
      apply prsumr_eq0P => i /Bool.negb_true_iff ->; first by intros; dispatch_Rgt.
        by rewrite Bool.andb_false_r //= !mulR0.
    }
    under eq_bigr => i _  do under eq_bigr => i0 _ do rewrite !eq_refl //= mulR1.
    under eq_bigr => i _  do under eq_bigr => i0 _ do rewrite ?mulR1.
    rewrite exchange_big //=.
    under eq_bigr => i0 _ do rewrite (bigID (fun i => i == Tuple (hash_vec_insert_length value hashes i0))) big_pred1_eq //=.
    rewrite addRA_rsum.
    erewrite H; last by []; last first.
    {
      do 1!(apply prsumr_eq0P; intros; first by intros; dispatch_Rgt).
      apply prsumr_eq0P => i Hneq; first by intros; dispatch_Rgt.
        by rewrite neg_hash_vecP //=; first rewrite !mulR0.
    }
    under eq_bigr => i _ do rewrite hash_vecP //=.
    have Hpred_eq i: (all (bloomfilter_get_bit^~ (bloomfilter_add_internal i bf)) inds = all (fun ind => ind \in i) inds).
    {
      apply eq_in_all => ind Hinds.
      case HinI: (ind \in i); first by rewrite /bloomfilter_get_bit bloomfilter_add_internal_hit //=.
      apply/Bool.negb_true_iff; rewrite /bloomfilter_get_bit bloomfilter_add_internal_miss //=;
                                        first by move/allP: Hall => /(_ ind Hinds) .
        by rewrite HinI.
    }
    under eq_bigr => i _ do rewrite Hpred_eq //=.
      by [].
  Qed.

  Lemma bloomfilter_add_multiple_unwrap_internal bf
        hashes l value (values: seq B) inds:
    length values == l ->
    hashes_have_free_spaces hashes (l.+1) ->
    all (hashes_value_unseen hashes) (value::values) ->
    \sum_(a in [finType of k.-tuple (HashState n) * BloomFilter])
     ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length value hashes inds)) bf
                                   values]) a *R*
      (d[ let (hashes2, bf) := a in res' <-$ bloomfilter_query value hashes2 bf; ret res'.2]) true) =
    \sum_(a in [finType of k.-tuple (HashState n) * BloomFilter])
     ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length value hashes inds)) bf
                                   values]) a *R*
      (bloomfilter_query_internal inds a.2 == true %R)).
  Proof.
    move: hashes; rewrite/hash_vec => hashes.
    move=>  Hlen Hfree Hall; apply eq_bigr => [[hshs' bf']] _.
    case Hzro: ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length value hashes inds)) bf values])
                  (hshs', bf') == 0); first by move/eqP:Hzro -> ; rewrite !mul0R.
    move/Bool.negb_true_iff: Hzro => Hzro.
    apply f_equal.
    rewrite //= /bloomfilter_query_internal //=.
    rewrite FDistBind.dE rsum_split //=.
    under eq_bigr => a _ do under eq_bigr => b _ do rewrite mulRC FDist1.dE eq_sym.
    under eq_bigr => a _ do rewrite -rsum_pred_demote big_pred1_eq FDistBind.dE rsum_split //=.
    under eq_bigr => a _ do under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite mulRC FDist1.dE xpair_eqE boolR_distr -mulRA.
    rewrite exchange_big //=; under eq_bigr => a0 _ do rewrite exchange_big.
     under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite -rsum_pred_demote big_pred1_eq //=.
    move=>//=.
    rewrite eqb_id; under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite eq_sym !eqb_id.
    have Hallleq: all
                    (fun hsh : FixedList.fixlist [eqType of hash_keytype * hash_valuetype] n =>
                       FixedList.fixlist_length hsh + 1 <= n) hashes.
    {
      move: Hfree;rewrite/hashes_have_free_spaces/hash_has_free_spaces=>/allP Hfree;apply/allP=>ind Hind.
        by move: (Hfree ind Hind); rewrite addn1 addnS =>/ltn_weaken.    
    }
    move: (@hash_vec_contains_value_base _ _ value hashes inds Hallleq) => Hcontains'.
    move: (@bloomfilter_add_multiple_find_preserve value inds (Tuple (hash_vec_insert_length value hashes inds)) hshs' bf bf' values Hcontains' Hzro) => Hcontains''.
    under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite (@hash_vec_find_simpl n k value hshs' _ inds _ Hcontains'') //=.
    under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite mulRC andbC boolR_distr -!mulRA.
    under eq_bigr => a0 _ do rewrite -rsum_pred_demote big_pred1_eq.
      by rewrite -rsum_pred_demote big_pred1_eq.
  Qed.

  Lemma bloomfilter_add_multiple_unwrap_base 
        hashes l (values: seq B) others inds:
    uniq values ->
    length values == l ->
    hashes_have_free_spaces (hashes: k.-tuple (HashState n)) (l) ->
    all (hashes_value_unseen hashes) (values) ->
    \sum_(a in [finType of (k.-tuple (HashState n) * BloomFilter)]%type)
     ((d[ bloomfilter_add_multiple hashes bloomfilter_new values]) a *R*
      ((all (bloomfilter_get_bit^~ (bloomfilter_add_internal others a.2)) inds == true) %R)) =
    \sum_(hits in [finType of (l * k).-tuple 'I_Hash_size.+1])
     ((inds \subseteq hits ++ others) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l * k)).
  Proof.
    elim: l others values inds => [//=| l IHl] others [//=|//= value values] inds Huniq Hlen Hfree Hunseen.
    - {
        under eq_bigr => a _ do rewrite FDist1.dE.
        rewrite -rsum_pred_demote big_pred1_eq //=.
        rewrite mul0n rsum_empty //= mulR1.
        rewrite eqb_id RIneq.INR_IZR_INZ; do?apply f_equal.
        apply eq_in_all => ind _; clear.
        case Hin: (ind \in others) => //=.
          by apply bloomfilter_add_internal_hit => //=.
          apply/Bool.negb_true_iff.
          apply bloomfilter_add_internal_miss => //=.
            by apply bloomfilter_new_empty_bits.
              by move/Bool.negb_true_iff: Hin.
      }
    - {
        move=>//=.
        move: (@subseq_imd ([finType of 'I_Hash_size.+1]) l k (fun hits => inds \subseteq hits ++ others)) => //=.
        rewrite card_ord => ->.
        have Hsusp b bs:  (inds \subseteq (b ++ bs) ++ others) = (inds \subseteq bs ++ (others ++ b)); first
          by rewrite -subseq_consA subseq_consC -subseq_consA.
        under [\sum_(b in [finType of k.-tuple _]) _]eq_bigr => b _ do under eq_bigr => bs _ do rewrite Hsusp.
        under  [\sum_(b in [finType of k.-tuple _]) _]eq_bigr => b _. {
          rewrite -(IHl (others ++ b) values inds) //=.
            by over.          
              by move/andP: Huniq => [].
              by move: Hfree;rewrite /hashes_have_free_spaces=>/allP Hall; apply/allP=> y Hy; move: (Hall y Hy);

              rewrite/hash_has_free_spaces addnS => /ltnW.
              by move/andP:Hunseen => [].
        }
        under eq_bigr => a _ do rewrite FDistBind.dE rsum_Rmul_distr_r rsum_split //=.
        under eq_bigr => a _ do under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite FDistBind.dE !rsum_Rmul_distr_l rsum_split //=.
        under eq_bigr => a _ do under eq_bigr => a0 _ do under eq_bigr => b _ do under eq_bigr => a1 _ do under eq_bigr => b0 _ do rewrite FDist1.dE.
        rewrite exchange_big.
          under eq_bigr => a0 _ do rewrite exchange_big.
          under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite exchange_big.
          under eq_bigr => a0 _ do under eq_bigr => b _ do under eq_bigr => a1 _ do rewrite exchange_big.
          under eq_bigr => a0 _ do under eq_bigr => b _ do under eq_bigr => a1 _ do 
          (under eq_bigr => a _ do under eq_bigr => c _ do
                 rewrite mulRA mulRC mulRA mulRC mulRA mulRC mulRA mulRA mulRC -mulRA).
          under eq_bigr => a0 _ do under eq_bigr => b _ do under eq_bigr => a1 _ do 
          under eq_bigr => b0 _ do rewrite -rsum_pred_demote big_pred1_eq.
        under eq_bigr => a0 _ do under eq_bigr => b _ do rewrite exchange_big.
        under eq_bigr => a0 _ do rewrite exchange_big.
        rewrite exchange_big.
        apply eq_bigr => b _ .
        rewrite rsum_Rmul_distr_l rsum_split //= [\sum_(a in _) (\sum_(b in _) (_ *R* _))]exchange_big.
        rewrite [\sum_(i in [finType of k.-tuple (HashState n)]) (\sum_(i0 in [finType of BloomFilter]) _)]exchange_big ; apply eq_bigr => bf' _.
        apply eq_bigr => hshs' _.
        rewrite -!rsum_Rmul_distr_l.
        rewrite mulRC -mulRA  mulRC -mulRA mulRC.
        apply Logic.eq_sym => //=.
        rewrite  -mulRA  mulRC -mulRA mulRC -mulRA.
        rewrite  bloomfilter_add_multiple_cat; apply f_equal.
        case Hzr0: ((d[ bloomfilter_add_multiple hashes bloomfilter_new values]) (hshs', bf') == 0);
          first by move/eqP: Hzr0 ->;rewrite mulR0 mul0R //=.
        move/Bool.negb_true_iff: Hzr0 => Hzr0.
        rewrite mulRC; apply f_equal; apply Logic.eq_sym.
        clear IHl.
        have H1:   (uniq (value :: values)); first by [].
        have H2: length values == l; first by move: Hlen =>/eqP [->].
        have H3: hashes_have_free_spaces hashes (l + 0).+1; first by rewrite addn0.
        have H4: all (hashes_value_unseen hashes) (value :: values); first by [].
        move: (@bloomfilter_add_multiple_preserve
                 value
                 values l 0 hashes hshs' bloomfilter_new bf'
                 H1 H2 H3 H4 Hzr0
              ) => /andP [Hfree' Huns'].
        move: (@hash_vec_simpl n k hshs' value b (fun _ => 1) Huns')=> //=.
        (under eq_bigr => a _ do rewrite mulR1); by move=>->; rewrite mulR1 //=.
      }
  Qed.

  Lemma bloomfilter_add_multiple_unwrap 
        hashes l value (values: seq B) inds:
    uniq (value::values) ->
    length values == l ->
    hashes_have_free_spaces (hashes: k.-tuple (HashState n)) (l.+1) ->
    all (hashes_value_unseen hashes) (value::values) ->
    \sum_(a in [finType of k.-tuple (HashState n) * BloomFilter])
     ((d[ bloomfilter_add_multiple (Tuple (hash_vec_insert_length value hashes inds)) bloomfilter_new
                                   values]) a *R*
      (d[ let (hashes2, bf) := a in res' <-$ bloomfilter_query value hashes2 bf; ret res'.2]) true) =
    \sum_(hits in [finType of (l * k).-tuple 'I_Hash_size.+1])
     ((inds \subseteq hits) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l * k)).
  Proof.      
    rewrite/bloomfilter_query //= => Huniq Hlen Hfree Hunseen.
    rewrite (@bloomfilter_add_multiple_unwrap_internal _ _ l) => //=.
    rewrite //= /bloomfilter_query_internal.
    move: Huniq => //=/andP[Hnin Huniq].
    move: (@bloomfilter_add_multiple_unwrap_base
             (Tuple (hash_vec_insert_length value hashes inds)) l values [::] inds Huniq Hlen
          ) => //=.
    under [   \sum_(hits in [finType of (l * k).-tuple 'I_Hash_size.+1]) _]eq_bigr => a _ do rewrite cats0.
    move=>-> //=.
    - {
        move: Hfree; rewrite/hashes_have_free_spaces/hash_has_free_spaces//=; clear.
        move=>/allP Hfree; apply/allP => [ //= hsh' /mapP [[hsh ind] /mem_zip/andP [Hhsh Hind] ->]].
        rewrite/hashstate_put //=.
        move: (Hfree hsh Hhsh); clear.      
        rewrite/FixedList.fixlist_length => //=.
        move=> H; apply/ fixedlist_add_incr;move: H.
          by rewrite addnS.
      }
    - {
        move/andP: Hunseen Hnin => [Huns ]; clear.
        rewrite/hashes_value_unseen //=; move=>/allP Hfree Hnin.
        apply/allP => [//= value' Hvalue]; move: (Hfree value' Hvalue)=>/allP  Hfree'.
        apply/allP => //= [ hsh' /mapP [[hsh ind] /mem_zip/andP [Hhsh Hind] ->]].
        move: (Hfree' hsh Hhsh ).
        move/memPn: Hnin => /(_ value' Hvalue); clear; rewrite /hash_unseen/hashstate_put.
          by move=> Hnew Hfind; apply fixmap_find_neq => //=.
      }
  Qed.    
  
  Theorem bloomfilter_collision_rsum
          hashes l value (values: seq B):
    length values == l ->
    hashes_have_free_spaces hashes (l.+1) ->
    all (hashes_value_unseen hashes) (value::values) ->
    uniq (value::values) ->
    d[ 
        res1 <-$ bloomfilter_query value hashes (bloomfilter_new);
          let (hashes1, init_query_res) := res1 in
          res2 <-$ @bloomfilter_add_multiple k n hashes1 (bloomfilter_new) values;
            let (hashes2, bf) := res2 in
            res' <-$ bloomfilter_query value hashes2 bf;
              ret (res'.2)
      ] true =
    \sum_(inds in [finType of k.-tuple ('I_Hash_size.+1)])
     ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ k) *R*
      (\sum_(hits in [finType of (l * k).-tuple 'I_Hash_size.+1])
        ((( inds \subseteq hits) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ (l * k)))))).
  Proof.
    have H x y z: (y = (0%R)) -> x = z -> x +R+ y = z. by move => -> ->; rewrite addR0.
    move=>//= Hlen Hfree /andP[Huns Halluns]/andP[Hnin Huniq].
    rewrite FDistBind.dE.
    (under eq_bigr => a _ do rewrite FDistBind.dE  rsum_Rmul_distr_r rsum_split exchange_big //=).
    rewrite exchange_big //=.
    (under eq_bigr => j _ do rewrite exchange_big//=).
    under eq_bigr => j _ do rewrite (bigID (fun i => i == Tuple (hash_vec_insert_length value hashes j))) big_pred1_eq hash_vecP //=.
    have Hfail j: 
      \sum_(i | i != Tuple (hash_vec_insert_length value hashes j))
       \sum_(i0 in ([finType of k.-tuple (HashState n) * bool]))
       ((d[ let (hashes1, _) := i0 in
            res2 <-$ bloomfilter_add_multiple hashes1 bloomfilter_new values;
            (let (hashes2, bf) := res2 in res' <-$ bloomfilter_query value hashes2 bf; ret res'.2)])
          true *R*
        ((d[ hash_vec_int value hashes]) (i, j) *R*
         (FDist1.d (i, bloomfilter_query_internal j bloomfilter_new)) i0)) = (0%R).
    {
      apply prsumr_eq0P => i Hni; first by dispatch_Rgt.
      apply prsumr_eq0P => i0 _; first by dispatch_Rgt.
      rewrite neg_hash_vecP //=  mul0R ?mulR0 //=.
    }
    under eq_bigr => j _ do rewrite Hfail addR0 //=.
    apply eq_bigr => inds _.
    under eq_bigr => i _ do rewrite FDist1.dE //=.
    rewrite rsum_split //=.
    under eq_bigr => a _ do under eq_bigr => b _ do rewrite xpair_eqE.
    move: (size_tuple inds) Hkgt0 => {1}<- Hiff.
    move/Bool.negb_true_iff: (bloomfilter_new_empty Hiff) => Hfalse.
    under eq_bigr => a _ do under eq_bigr => b _ do rewrite Hfalse //=.
    rewrite (bigID (fun a => a == Tuple (hash_vec_insert_length value hashes inds))) big_pred1_eq//=.
    apply H; first by apply prsumr_eq0P => i /Bool.negb_true_iff -> //=; rewrite !mulR0 bigsum_card_constE mulR0; try ( right).
    under eq_bigr => b _ do rewrite eq_refl //=.
    rewrite (bigID (fun b => b == false)) big_pred1_eq //=.
    apply H; first by rewrite (eq_bigl (fun i => i == true)); first rewrite big_pred1_eq //= !mulR0; last by case.
    rewrite mulR1 mulRC; apply f_equal.
    rewrite FDistBind.dE.
    erewrite  bloomfilter_add_multiple_unwrap => //=.
      by apply/andP; split=>//=.
        by apply/andP; split=>//=.
  Qed.

  Lemma subseq_conv l:
    \sum_(inds in [finType of k.-tuple ('I_Hash_size.+1)])
     ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ k) *R*
      (\sum_(hits in [finType of (l * k).-tuple 'I_Hash_size.+1])
        ((( inds \subseteq hits) *R* (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ (l * k)))))) =
    ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l.+1 * k) *R*
     \sum_(a in ordinal_finType (Hash_size.+2))
      (((((a %R) ^R^ k) *R* (Factorial.fact a %R)) *R* ('C(Hash_size.+1, a) %R)) *R* stirling_no_2 (l * k) a)).
  Proof.
    under eq_bigr => inds _ do rewrite rsum_Rmul_distr_l.
    rewrite exchange_big.
    under eq_bigr => inds _ do under eq_bigr => inds' _ do rewrite mulRA mulRC.
    under eq_bigr => inds _ do rewrite -rsum_Rmul_distr_l.
    under eq_bigr => inds _ do under eq_bigr => inds' _ do rewrite mulRC.
    have Hbool inds' inds: (inds' \subseteq inds %R) = (inds' \subseteq inds); first by rewrite RIneq.INR_IZR_INZ.
    under eq_bigr => inds _ do under eq_bigr => ps _ do rewrite -Hbool.
    under eq_bigr => inds _ do rewrite -rsum_pred_demote.
    under eq_bigr => inds _.
    rewrite rsum_subseq_mult_undup_eq rsum_subseq_mult //=.
    by over.
      by apply undup_uniq.
      move=>//=.
      
      move:  ( bloomfilter_second_stirling_number_sum l k Hash_size
                                         (fun len => (((len %R) *R* Rdefinitions.Rinv (Hash_size.+1 %R)) ^R^ k))
             ) => //= ->.
      have H len: ((((len %R) *R* Rdefinitions.Rinv (Hash_size.+1 %R)) ^R^ k) *R*
                   (((('C(Hash_size.+1, len) %R) *R* (Factorial.fact len %R)) *R* stirling_no_2 (l * k) len) *R*
                    (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l * k))) = (
                    (Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ (l.+1 * k)) *R* (
                      ((len %R) ^R^ k) *R*
                      (Factorial.fact len %R) *R*
                      ('C (Hash_size.+1, len) %R) *R*
                      (stirling_no_2 (l * k) len)
                  )).
      {
        rewrite expRM -mulRA.
        apply Logic.eq_sym.
        rewrite mulRC -!mulRA; apply f_equal.
        rewrite mulRC; apply Logic.eq_sym; rewrite mulRC -!mulRA; apply f_equal.
        rewrite mulRC mulRA mulRA mulRC mulRA mulRC.
        rewrite mulRC mulRA; apply Logic.eq_sym.
        rewrite mulRA mulRA mulRC -!mulRA; do?apply f_equal.
        rewrite mulSnr //=.
          by rewrite Rfunctions.pow_add.    
      }
      under eq_bigr => len _ do rewrite H.
      by rewrite -rsum_Rmul_distr_l.
  Qed.

  Theorem bloomfilter_collision_prob
          hashes l value (values: seq B):
    length values == l ->
    hashes_have_free_spaces hashes (l.+1) ->
    all (hashes_value_unseen hashes) (value::values) ->
    uniq (value::values) ->
    d[ 
        res1 <-$ bloomfilter_query value hashes (bloomfilter_new);
          let (hashes1, init_query_res) := res1 in
          res2 <-$ @bloomfilter_add_multiple k n hashes1 (bloomfilter_new) values;
            let (hashes2, bf) := res2 in
            res' <-$ bloomfilter_query value hashes2 bf;
              ret (res'.2)
      ] true =
    ((Rdefinitions.Rinv (Hash_size.+1 %R) ^R^ l.+1 * k) *R*
     \sum_(a in ordinal_finType (Hash_size.+2))
      (((((a %R) ^R^ k) *R* (Factorial.fact a %R)) *R* ('C(Hash_size.+1, a) %R)) *R* stirling_no_2 (l * k) a)).
  Proof.
    intros; rewrite (@bloomfilter_collision_rsum _ l) => //=.
      by rewrite  subseq_conv.
  Qed.

End BloomFilter.

Print Assumptions  bloomfilter_collision_prob.
(* Local Variables: *)
(* company-coq-local-symbols: (("\\subseteq" . ?⊆)) *)
(* End: *)
