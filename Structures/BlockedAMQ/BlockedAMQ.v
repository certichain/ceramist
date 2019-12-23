From mathcomp.ssreflect
     Require Import ssreflect ssrbool ssrnat eqtype fintype choice ssrfun seq path bigop finfun .
From mathcomp.ssreflect
     Require Import tuple.
From mathcomp
     Require Import path.

From infotheo Require Import
     ssrR Reals_ext logb ssr_ext ssralg_ext bigop_ext Rbigop proba.

Require Import Coq.Logic.ProofIrrelevance.
Require Import Coq.Logic.FunctionalExtensionality.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

From ProbHash.Utils
     Require Import InvMisc  seq_ext seq_subset rsum_ext stirling tactics.

From ProbHash.Computation
     Require Import Comp Notationv1.

From ProbHash.Core
     Require Import Hash HashVec FixedList FixedMap.

Lemma index_enum_simpl y: ((index_enum y)) = (index_enum [finType of y]).
Proof.
    by rewrite /index_enum //= /[finType of _] //=; case: y => //=.
Qed.



Module Type AMQHASH.
  Parameter AMQHashKey : finType.

  (* for some reason this doesn't compute automatically *)
  Axiom finType_AMQHashKey:  [finType of AMQHashKey] = AMQHashKey.

  Parameter AMQHashValue : finType.

  
  Parameter AMQHashParams: Type.
  Parameter AMQHash : AMQHashParams -> finType.

  

  Section AMQHash.
    Variable p: AMQHashParams. 
    Parameter AMQHash_probability:  AMQHashParams -> Rdefinitions.R.

    Section HashProbability.

      Variable h: AMQHashParams.

      Axiom AMQHash_hash_prob_valid:
        \sum_(v in  AMQHashValue) (AMQHash_probability h) = 1.

    End HashProbability.

    (* deterministic pure transformations of hash state  *)
    Parameter AMQHash_hashstate_find : AMQHash p -> AMQHashKey -> option AMQHashValue.
    Parameter AMQHash_hashstate_put : AMQHash p -> AMQHashKey -> AMQHashValue -> AMQHash p.

    (* boolean properties of hash states*)
    Parameter AMQHash_hashstate_available_capacity : AMQHash p -> nat -> bool.
    Parameter AMQHash_hashstate_valid: AMQHash p -> bool.
    Parameter AMQHash_hashstate_contains: AMQHash p -> AMQHashKey -> AMQHashValue -> bool.
    Parameter AMQHash_hashstate_unseen: AMQHash p -> AMQHashKey -> bool.

    (* probabilistic hash operation*)
    Parameter AMQHash_hash: AMQHash p -> AMQHashKey -> Comp [finType of (AMQHash p * AMQHashValue)].

    (* properties of deterministic hash state operations *)
    Section DeterministicOperations.

      Variable hashstate: AMQHash p.


      Axiom AMQHash_hashstate_contains_findE: forall (key: AMQHashKey) (value: AMQHashValue) ,
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_contains hashstate key value ->
          AMQHash_hashstate_find  hashstate key = Some value.

      Axiom AMQHash_hashstate_unseen_nfindE: forall (key: AMQHashKey) (value: AMQHashValue),
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_unseen hashstate key ->
          AMQHash_hashstate_find  hashstate key = None.

      Axiom AMQHash_hashstate_available_capacityW: forall n m, m <= n ->
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_available_capacity hashstate n ->
          AMQHash_hashstate_available_capacity hashstate m.

      Axiom AMQHash_hashstate_available_capacity_decr: forall l key value,
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_available_capacity hashstate l.+1 ->
          AMQHash_hashstate_available_capacity (AMQHash_hashstate_put hashstate key value) l.
      
      
      Axiom  AMQHash_hashstate_add_contains_preserve: forall (key key': AMQHashKey) (value value': AMQHashValue),
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_available_capacity hashstate 1 -> 
          key != key' -> AMQHash_hashstate_contains hashstate key value ->
          AMQHash_hashstate_contains (AMQHash_hashstate_put  hashstate key' value') key value.

      Axiom  AMQHash_hashstate_add_contains_base: forall (key: AMQHashKey) (value: AMQHashValue),
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_available_capacity hashstate 1 ->
        AMQHash_hashstate_contains (AMQHash_hashstate_put  hashstate key value) key value.

      Axiom AMQHash_hashstate_add_valid_preserve: forall (key: AMQHashKey) (value: AMQHashValue), 
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_available_capacity hashstate 1 -> 
          AMQHash_hashstate_valid (AMQHash_hashstate_put  hashstate key value).

      Axiom AMQHash_hashstate_unseenE: forall (hashstate': AMQHash p) (key key': AMQHashKey) (value value': AMQHashValue),
          key != key' ->
          AMQHash_hashstate_unseen hashstate key ->
          hashstate' = AMQHash_hashstate_put hashstate key' value' ->
          AMQHash_hashstate_unseen hashstate' key.

    End DeterministicOperations.

    
    Axiom  AMQHash_hash_unseen_insert_eqE: forall (hashstate hashstate': AMQHash p) (key: AMQHashKey) (value: AMQHashValue),
          AMQHash_hashstate_unseen hashstate key -> hashstate' = AMQHash_hashstate_put hashstate key value ->
          d[ AMQHash_hash hashstate key ] (hashstate', value) = AMQHash_probability p.

    Axiom  AMQHash_hash_unseen_insert_neqE: forall (hashstate hashstate': AMQHash p) (key: AMQHashKey) (value: AMQHashValue),
          AMQHash_hashstate_unseen hashstate key -> hashstate' != AMQHash_hashstate_put hashstate key value ->
          d[ AMQHash_hash hashstate key ] (hashstate', value) = 0.

    Axiom AMQHash_hash_seen_insertE: forall (hashstate hashstate': AMQHash p) (key: AMQHashKey) (value value': AMQHashValue),
        AMQHash_hashstate_contains hashstate key value ->
        d[ AMQHash_hash hashstate key ] (hashstate', value') = ((hashstate' == hashstate) && (value' == value)).
        
  End AMQHash.    
End AMQHASH.

Module AMQHashProperties (AMQHash: AMQHASH).

  Import AMQHash.
  Section Properties.
    Variable p: AMQHashParams. 
    
    Lemma AMQHash_hash_unseen_simplE (hashstate: AMQHash p) key value f :
        AMQHash_hashstate_unseen hashstate key ->
        (\sum_(hashstate' in [finType of AMQHash p])
         (d[ AMQHash_hash hashstate key ] (hashstate', value) *R* (f hashstate'))) =
        ((AMQHash_probability p) *R*
         (f (AMQHash_hashstate_put hashstate key value))).
    Proof.
      move=> Hall.
      rewrite (bigID (fun hashstate' => hashstate' == (AMQHash_hashstate_put hashstate key value))) //=.
      rewrite (@big_pred1_eq Rdefinitions.R _ _
                             [finType of AMQHash p]
                             (AMQHash_hashstate_put hashstate key value))//=.
      under eq_bigr => i Hneq do rewrite AMQHash_hash_unseen_insert_neqE //= ?mul0R.
      rewrite AMQHash_hash_unseen_insert_eqE //=.
      rewrite (@bigsum_card_constE [finType of AMQHash p] ) mulR0 addR0 //=.
    Qed.

  End Properties.
End AMQHashProperties.


Module Type AMQ (AMQHash: AMQHASH).


  Parameter AMQStateParams : Type.
  Parameter AMQState : AMQStateParams -> finType.


  Section AMQ.
    Variable p: AMQStateParams.
    Parameter AMQ_hash_vec_size: AMQStateParams -> nat.
    
    Parameter AMQ_add_internal: AMQState p -> AMQHash.AMQHashValue -> AMQState p.
    Parameter AMQ_query_internal: AMQState p -> AMQHash.AMQHashValue -> bool.
    Parameter AMQ_available_capacity: AMQState p -> nat -> bool.
    Parameter AMQ_valid: AMQState p -> bool.

    Axiom AMQ_new: AMQState p.
    Axiom AMQ_new_nqueryE: forall vals, ~~ AMQ_query_internal  AMQ_new vals.
    Axiom AMQ_new_validT: AMQ_valid AMQ_new.

    Section DeterministicProperties.
      Variable amq: AMQState p.

      Axiom AMQ_available_capacityW: forall  n m,
          AMQ_valid amq -> m <= n -> AMQ_available_capacity amq n -> AMQ_available_capacity amq m.

    Axiom AMQ_add_query_base: forall (amq: AMQState p) inds,
        AMQ_valid amq -> AMQ_available_capacity amq 1 ->
        AMQ_query_internal (AMQ_add_internal amq inds) inds.

    Axiom AMQ_add_valid_preserve: forall (amq: AMQState p) inds,
        AMQ_valid amq -> AMQ_available_capacity amq 1 ->
        AMQ_valid (AMQ_add_internal amq inds).

    Axiom AMQ_add_query_preserve: forall (amq: AMQState p) inds inds',
        AMQ_valid amq -> AMQ_available_capacity amq 1 -> AMQ_query_internal amq inds ->
        AMQ_query_internal (AMQ_add_internal amq inds') inds.

    Axiom AMQ_add_capacity_decr: forall (amq: AMQState p) inds l,
        AMQ_valid amq -> AMQ_available_capacity amq l.+1 ->
        AMQ_available_capacity (AMQ_add_internal amq inds) l.
    
    Axiom AMQ_query_valid_preserve: forall (amq: AMQState p) inds,
        AMQ_valid amq -> AMQ_valid (AMQ_add_internal amq inds).

    Axiom AMQ_query_capacity_preserve: forall (amq: AMQState p) inds l,
        AMQ_valid amq -> AMQ_available_capacity amq l.+1 -> AMQ_available_capacity (AMQ_add_internal amq inds) l.

    End DeterministicProperties.
  End AMQ.
End AMQ.

Module AMQOperations (AmqHash: AMQHASH) (Amq: AMQ AmqHash) .

  Export Amq.
  Export AmqHash.

  Module AmqHashProperties := (AMQHashProperties AmqHash).
  Import AmqHashProperties.

  Section Operations.

    Variable h : AMQHashParams.
    Variable s: AMQStateParams.

    Definition AMQ_add (amq: AMQState s)   (hashes: AMQHash h) (value: AMQHashKey) :
      Comp [finType of (AMQHash h) * AMQState s] :=
      hash_res <-$ (AMQHash_hash  hashes value);
      let (new_hashes, hash_vec) := hash_res in
      let new_amq := AMQ_add_internal amq hash_vec in
      ret (new_hashes, new_amq).

    Definition AMQ_query (amq: AMQState s)   (hashes: AMQHash h) (value: AMQHashKey) :
      Comp [finType of (AMQHash h) * bool] :=
      hash_res <-$ (AMQHash_hash  hashes value);
      let (new_hashes, hash_vec) := hash_res in
      let new_amq := AMQ_query_internal amq hash_vec in
      ret (new_hashes, new_amq).
    

    Definition AMQ_add_multiple  hsh_0 bf_0 values :=
    @foldr _ (Comp [finType of AMQHash h * AMQState s])
           (fun val hsh_bf =>
              res_1 <-$ hsh_bf;
                let (hsh, bf) := res_1 in
                AMQ_add bf hsh val) (ret (hsh_0, bf_0)) values.
  End Operations.

  Section Properties.
    Variable h : AMQHashParams.
    Variable s: AMQStateParams.

    Variable hashes: AMQHash h.
    Variable amq: AMQState s.

    Lemma AMQ_add_multiple_properties_preserve  ( cbf': AMQState s)  values inds' l m:
            length values == l -> AMQ_valid amq ->  AMQ_available_capacity amq (l + m) ->
            (P[ AMQ_add_multiple hashes amq values === (inds', cbf')] != 0) ->
            AMQ_valid cbf' && AMQ_available_capacity cbf' m.
          Proof.
            move=>/eqP <-; clear l.
            elim: values m amq cbf' inds' => [| x xs Hxs] m cbf cbf' inds' Hvalid Havail //=; comp_normalize;
            first by move=>/bool_neq0_true; rewrite xpair_eqE=>/andP[_ /eqP -> ]; apply/andP => //=.
            exchange_big_outwards 2 => //=; comp_simplify_n 1; comp_possible_decompose.
            move=> cbf'' inds'' Hind Haddm Hhash /bool_neq0_true/eqP ->.
            move: Havail => //=; rewrite addSn -addnS => Havail.
            move: (@Hxs m.+1 cbf inds'' cbf'' Hvalid Havail Haddm); clear Hxs Haddm => /andP [Hvalid' Hfree'].
            apply/andP;split.
            apply AMQ_add_valid_preserve => //=; apply AMQ_available_capacityW with (n:= m.+1) => //=.
            apply AMQ_add_capacity_decr => //=.
          Qed.

  End Properties.

  Section Query.
    Variable h : AMQHashParams.
    Variable s: AMQStateParams.

    Variable hashes: AMQHash h.
    Variable amq: AMQState s.

    Lemma AMQ_add_multiple_query_preserve  ( amq': AMQState s)  values inds inds' l:
      length values == l -> AMQ_valid amq ->  AMQ_available_capacity amq l -> AMQ_query_internal amq inds ->
      (P[ AMQ_add_multiple hashes amq values === (inds', amq')] != 0) ->
      AMQ_query_internal amq' inds.
    Proof.
      move=>/eqP <-; clear l.
      elim: values amq amq' inds inds' => [| x xs Hxs] cbf cbf' inds inds' Hvalid Havail Hquery //=; comp_normalize;
                                            first by move=>/bool_neq0_true; rewrite xpair_eqE =>/andP [ _ /eqP ->].
      exchange_big_outwards 2 => //=; comp_simplify_n 1; comp_possible_decompose.
      move=> cbf'' inds'' Hind Haddm Hhash /bool_neq0_true/eqP ->.
      move: Havail => //=; rewrite -addn1 => Havail.
      move: (@AMQ_add_multiple_properties_preserve h s hashes cbf inds'' xs cbf'' (length xs) 1 (eq_refl (length xs)) Hvalid Havail Haddm) => /andP [Hvalid' Hcap'].
      apply AMQ_add_query_preserve => //=.
      eapply Hxs with (amq:= cbf) (inds':= cbf'') => //=.
      by apply AMQ_available_capacityW with (n:= length xs + 1) => //=; last  rewrite addn1.
    Qed.
    
  End Query.

  Section HashProperties.
    Variable h : AMQHashParams.
    Variable s: AMQStateParams.

    Variable hashes: AMQHash h.
    Variable amq: AMQState s.

    Lemma AMQ_add_multiple_hash_properties_preserve  ( amq': AMQState s)  x xs  inds' l m 
          (Hlen: length xs == l) (Huniq: uniq (x :: xs)) (Hfree: AMQHash_hashstate_available_capacity hashes  ((l+m))) (Hvalid: AMQHash_hashstate_valid hashes)
          (Huns: all (AMQHash_hashstate_unseen hashes) (x :: xs)):
      (P[ AMQ_add_multiple hashes amq xs === (inds', amq')] != 0) ->
      (AMQHash_hashstate_available_capacity inds' (m)) && (AMQHash_hashstate_unseen inds' x) && (AMQHash_hashstate_valid inds').
    Proof.
      move: Hlen Hvalid Huniq Hfree Huns; move=>/eqP <-; clear l.
      elim: xs x m amq amq' hashes inds' => [| y ys Hxs] x m cbf cbf' hshs hshs' Hvalid Huni Hcap Huns //=; comp_normalize.
      - by move=>/bool_neq0_true; rewrite xpair_eqE =>/andP [ /eqP -> _]; move: Hcap Huns => //=; rewrite add0n => ->/andP[->] //=.
      - exchange_big_outwards 2 => //=; comp_simplify_n 1; comp_possible_decompose.
        move=> hsh'' cbf'' y' Haddm Hhash /bool_neq0_true/eqP Hcbf.
        have H1: uniq (y :: ys); first by move: Huni => //= /andP[ _ -> ].
        have H1': uniq (x :: ys);
          first by move: Huni => //= /andP[ ]; rewrite in_cons Bool.negb_orb => /andP[ _ ->] /andP[ _ ->].
        have H2: AMQHash_hashstate_available_capacity hshs (length ys + m.+1);
          first by move: Hcap => //=; rewrite addSn -addnS.
        have H3: all (AMQHash_hashstate_unseen hshs) (y :: ys);
          first by move: Huns => //=/andP[ _ ->].
        have H3': all (AMQHash_hashstate_unseen hshs) (x :: ys);
          first by move: Huns => //=/andP[ -> /andP [ _ ->]  ].
        move: (@Hxs y m.+1 cbf cbf'' hshs hsh'' Hvalid H1 H2 H3 Haddm) => /andP [/andP [Hcap' Huns'] Hvalid'].
        move: (@Hxs x m.+1 cbf cbf'' hshs hsh'' Hvalid H1' H2 H3' Haddm) => /andP [/andP [_ Hunsx'] _].
      case Heq: (hshs' != AMQHash_hashstate_put hsh'' y y').
      - by move: (AMQHash_hash_unseen_insert_neqE Huns' Heq) Hhash => -> //= /eqP //=.
      - move/Bool.negb_false_iff: Heq => /eqP ->.
        apply /andP; split; first apply/andP; first split => //=.
        by apply  AMQHash_hashstate_available_capacity_decr => //=.
        apply AMQHash_hashstate_unseenE with (hashstate:=hsh'') (key' := y) (value':=y') => //=.
        by move: Huni => //=/andP[]; rewrite in_cons Bool.negb_orb => /andP[].
        apply AMQHash_hashstate_add_valid_preserve => //=.
        apply AMQHash_hashstate_available_capacityW with (n:=m.+1) => //=.
    Qed.
  End HashProperties.

  Section HashProperties.
    Variable h : AMQHashParams.
    Variable s: AMQStateParams.

    Variable hashes: AMQHash h.
    Variable amq: AMQState s.


    Lemma AMQ_add_multiple_hash_contains_preserve  ( amq': AMQState s)  x ind xs  inds' l 
          (Hlen: length xs == l) (Huniq: uniq (x :: xs))
          (Hfree: AMQHash_hashstate_available_capacity hashes  l)
          (Hvalid: AMQHash_hashstate_valid hashes)
          (Huns: all (AMQHash_hashstate_unseen hashes) xs)
          (Hseen:  AMQHash_hashstate_contains hashes x ind):
      (P[ AMQ_add_multiple hashes amq xs === (inds', amq')] != 0) ->
      (AMQHash_hashstate_contains inds' x ind).
    Proof.
      move: Hlen Hvalid Huniq Hfree Huns Hseen; move=>/eqP <-; clear l.
      elim: xs x amq amq' hashes inds' => [| y ys Hxs] x  cbf cbf' hshs hshs' Hvalid Huni Hcap Huns Hcont //=; comp_normalize.
      - by move=>/bool_neq0_true; rewrite xpair_eqE =>/andP [ /eqP -> _]; move: Hcap Hcont => //=; rewrite add0n => ->/andP[->] //=.
      - exchange_big_outwards 2 => //=; comp_simplify_n 1; comp_possible_decompose.
        move=> hsh'' cbf'' y' Haddm Hhash /bool_neq0_true/eqP Hcbf.
        have H1: uniq (y :: ys); first by move: Huni => //= /andP[ _ -> ].
        have H1': uniq (x :: ys);
          first by move: Huni => //= /andP[ ]; rewrite in_cons Bool.negb_orb => /andP[ _ ->] /andP[ _ ->].

        have H2: (AMQHash_hashstate_available_capacity hshs (length ys)). {
            by move: Hcap => //=; apply AMQHash_hashstate_available_capacityW.          
        }

        have H3: (all (AMQHash_hashstate_unseen hshs) ys). {
          by move: Huns => //= /andP[].
        }
        move: Hhash (@Hxs x cbf cbf'' hshs hsh'' Hvalid H1' H2 H3 Hcont  Haddm).
        have Huniys: (uniq (y :: ys)); first by move: Huni => //=.
        move: Hcap => //= Hcap.
        move:(@AMQ_add_multiple_hash_properties_preserve h s hshs cbf cbf''  y ys hsh'' (length ys) 1 (eq_refl (length ys)) Huniys);
          rewrite addn1 =>/(_ Hcap Hvalid Huns Haddm) => /andP[/andP[Hcap' Hunsy] Hvalidhsh'].
        case Hneq: (hshs' != AMQHash_hashstate_put hsh'' y y').
        {
          - move: Huns => //=/andP[Hyun Huns].
            by move: (AMQHash_hash_unseen_insert_neqE Hunsy  Hneq) -> => /eqP //=.
        }
        {
          - move/Bool.negb_true_iff: Hneq; rewrite Bool.negb_involutive => /eqP -> Hn0 Hcontains.  
            apply AMQHash_hashstate_add_contains_preserve => //=.
            by move: Huni => //= /andP []; rewrite in_cons Bool.negb_orb => /andP[].
        }        
    Qed.

    End HashProperties.

  Section FalseNegatives.
    Variable h : AMQHashParams.
    Variable s: AMQStateParams.

    Theorem AMQ_no_false_negatives (hashes: AmqHash.AMQHash h)  (amq: AMQState s) l x xs:
      uniq (x :: xs) -> length xs == l ->
      AMQ_valid amq -> AMQ_available_capacity amq l.+1 ->

      AmqHash.AMQHash_hashstate_valid hashes ->
      AmqHash.AMQHash_hashstate_available_capacity hashes l.+1 ->

      all (AmqHash.AMQHash_hashstate_unseen hashes) (x::xs) ->
      (d[ res1 <-$ AMQ_add amq hashes x;
          let '(hsh1, amq1) := res1 in
          res2 <-$ AMQ_add_multiple hsh1 amq1 xs;
            let '(hsh2, amq2) := res2 in
            res3 <-$ AMQ_query amq2 hsh2 x;
              ret (snd res3) ] true) = (1 %R).
    Proof.
      move=> Huniq Hlen Hamqvalid Hamqavail Hvalid Havail Hall.
      comp_normalize; comp_simplify_n 2.
      exchange_big_outwards 5 => //=; comp_simplify_n 1.
      exchange_big_outwards 4 => //=; comp_simplify_n 1.
      have ->: ((index_enum (AMQHash h))) = (index_enum [finType of AMQHash h]); first by clear;  rewrite index_enum_simpl //=.
      move: Hall => //=/andP[Hallx Hall].
      exchange_big_outwards 2 => //=; exchange_big_inwards ltac:(rewrite AmqHashProperties.AMQHash_hash_unseen_simplE //= mulRA [(AmqHash.AMQHash_probability h) *R* _]mulRC -!mulRA).

      under eq_bigr => hshs' _. {
        under eq_bigr => amq' _; first under eq_bigr => ind _; first under eq_bigr => hshs'' _;
        first under eq_rsum_ne0  => ind' Hn0.

        have Hvalidamqin: (AMQ_valid (AMQ_add_internal amq ind)). {
          apply AMQ_add_valid_preserve=>//=.          
          by apply AMQ_available_capacityW with (n:=l.+1)=>//=.
        }
        have Hvalidin: (AmqHash.AMQHash_hashstate_valid (AmqHash.AMQHash_hashstate_put hashes x ind)).
        {
          apply AmqHash.AMQHash_hashstate_add_valid_preserve => //=.
          by apply AmqHash.AMQHash_hashstate_available_capacityW with (n:=l.+1)=>//=.
        }
        have Havailamqin: (AMQ_available_capacity (AMQ_add_internal amq ind) l); first
          by apply AMQ_add_capacity_decr => //=.

        have Hqueryamqin: (AMQ_query_internal (AMQ_add_internal amq ind) ind). {
          apply AMQ_add_query_base => //=.
          by apply AMQ_available_capacityW with (n:=l.+1)=>//=.
        }

        have Hin: (AMQHash_hashstate_contains hshs' x ind). {
          eapply (@AMQ_add_multiple_hash_contains_preserve)
            with (hashes:=(AmqHash.AMQHash_hashstate_put hashes x ind))
                 (amq:=(AMQ_add_internal amq ind))
                 (amq':=amq')
                 (xs:=xs)
          => //=.
          {
            - apply AMQHash_hashstate_available_capacity_decr => //=.
                by move/eqP: Hlen Havail => ->.
          }
          {
            apply/allP => v Hv.
            apply AmqHash.AMQHash_hashstate_unseenE with
                (key':=x) (value':=ind) (hashstate:=hashes) => //=.
              by move: Huniq => //=/andP[/memPn Hvv _]; move: (Hvv v Hv).
                by move/allP: Hall => /(_ v Hv).
          }
          apply AmqHash.AMQHash_hashstate_add_contains_base => //=.
            by apply AmqHash.AMQHash_hashstate_available_capacityW with (n:=l.+1).
        }
        rewrite (@AmqHash.AMQHash_hash_seen_insertE _ _ _ _ _ _ Hin) => //=.
        rewrite mulRA [_ *R* (_ && _)]mulRC -!mulRA.

        rewrite -RIneq.INR_IZR_INZ boolR_distr.
        by over. by over. by over. by over. by over.
      }
      comp_normalize.
      under_all ltac:(rewrite mulRC -!mulRA ).
      under eq_bigr => i _. {
        under eq_bigr => i0 _ ; first under eq_bigr => i1 _.
        rewrite exchange_big => //=; under eq_bigr => i3 _.
        rewrite -(@rsum_pred_demote [finType of AmqHash.AMQHash h]) big_pred1_eq; over => //=.
        rewrite index_enum_simpl //=.
        rewrite -(@rsum_pred_demote [finType of AmqHash.AMQHashValue]) big_pred1_eq.
        by over. by over. by over.
      }
      under_all ltac:(rewrite mulRC [(_ %R) *R* _]mulRC -!mulRA).
      under eq_bigr => hshs' _. { 
        under eq_bigr => amq' _; first under eq_rsum_ne0 => ind Hn0.
        have Hvalidamqin: (AMQ_valid (AMQ_add_internal amq ind)). {
          apply AMQ_add_valid_preserve=>//=.          
            by apply AMQ_available_capacityW with (n:=l.+1)=>//=.
        }
        have Hvalidin: (AmqHash.AMQHash_hashstate_valid (AmqHash.AMQHash_hashstate_put hashes x ind)).
        {
          apply AmqHash.AMQHash_hashstate_add_valid_preserve => //=.
          by apply AmqHash.AMQHash_hashstate_available_capacityW with (n:=l.+1)=>//=.
        }
        have Havailamqin: (AMQ_available_capacity (AMQ_add_internal amq ind) l); first
          by apply AMQ_add_capacity_decr => //=.

        have Hqueryamqin: (AMQ_query_internal (AMQ_add_internal amq ind) ind). {
          apply AMQ_add_query_base => //=.
         by apply AMQ_available_capacityW with (n:=l.+1)=>//=.
        }

        have Hqueryint: (AMQ_query_internal amq' ind). {

          apply AMQ_add_multiple_query_preserve
            with (hashes:=(AmqHash.AMQHash_hashstate_put hashes x ind))
                 (values:= xs)
                 (amq:=(AMQ_add_internal amq ind))
                 (amq':=amq')
                 (inds':=hshs')
                 (l:=l)
                 => //=.
        }
        rewrite Hqueryint eq_refl //= mul1R.

        by over.
        by over.
        by over.
      }
      move=>//=.

      exchange_big_outwards 2 => //=.
      under eq_bigr do under eq_bigr do rewrite -big_distrl //=.
      under eq_bigr do rewrite -big_distrl //=.
      under eq_bigr do rewrite mulRC.
      under eq_bigr => i Hi.
      rewrite -index_enum_simpl.
      suff ->:  \sum_(i0 in  AmqHash.AMQHash h)
         \sum_(i1 in   AMQState s)
            P[ AMQ_add_multiple
                 (AmqHash.AMQHash_hashstate_put hashes x i)
                 (AMQ_add_internal amq i) xs === 
                 (i0, i1)] = 1;
        last first; last rewrite mulR1; last by over.
      by rewrite -rsum_split //=; apply FDist.f1.
      move=> //=.
      by rewrite AmqHash.AMQHash_hash_prob_valid.
    Qed.
  End FalseNegatives.

End AMQOperations.

Module Type AMQProperties (AmqHash: AMQHASH) (AbstractAMQ: AMQ AmqHash) .
  Module AmqOperations := AMQOperations (AmqHash)  (AbstractAMQ).
  Import AmqOperations.

  Parameter AMQ_false_positive_probability:  AMQHashParams -> AMQStateParams -> nat -> Rdefinitions.R.

  Section Properties.
    Variable h : AMQHashParams.
    Variable s: AMQStateParams.

    Variable hashes: AMQHash h.
    Variable amq: AMQState s.

    Axiom AMQ_no_false_negatives:
      forall (l:nat_eqType) (x:AMQHashKey) (xs: seq AMQHashKey),
        uniq (x :: xs) -> length xs == l ->

        AMQ_valid amq -> AMQ_available_capacity amq l.+1 ->

        AMQHash_hashstate_valid hashes ->
        AMQHash_hashstate_available_capacity hashes l.+1 ->

        all (AMQHash_hashstate_unseen hashes) (x::xs) ->
        (d[ res1 <-$ AMQ_add amq hashes x;
          let '(hsh1, amq1) := res1 in
          res2 <-$ AMQ_add_multiple hsh1 amq1 xs;
            let '(hsh2, amq2) := res2 in
            res3 <-$ AMQ_query amq2 hsh2 x;
              ret (snd res3) ] true) = (1 %R).

    Axiom AMQ_false_positives_rate: forall  l value (values: seq _),
        length values == l ->

        AMQHash_hashstate_valid hashes ->
        AMQHash_hashstate_available_capacity hashes (l.+1) ->

        all (AMQHash_hashstate_unseen hashes) (value::values) ->
        uniq (value::values) ->
        d[ 
            res1 <-$ AMQ_query (AMQ_new s) hashes value;
              let (hashes1, init_query_res) := res1 in
              res2 <-$ AMQ_add_multiple hashes1 (AMQ_new s) values;
                let (hashes2, amq) := res2 in
                res' <-$ AMQ_query amq  hashes2 value;
                  ret (res'.2)
          ] true = AMQ_false_positive_probability h s l.

  End Properties.

End AMQProperties.



Module Type AMQMAP (AmqHash: AMQHASH) (A: AMQ AmqHash) (B: AMQ AmqHash).

  Parameter AMQ_param_map: A.AMQStateParams -> B.AMQStateParams.
  Parameter AMQ_state_map:  forall p: A.AMQStateParams, A.AMQState p -> B.AMQState (AMQ_param_map p).

  Section Map.

    Variable p: A.AMQStateParams.
    
    Axiom AMQ_map_add_internalE: forall (a: A.AMQState p) val, A.AMQ_valid a -> A.AMQ_available_capacity a 1 ->
      B.AMQ_add_internal (AMQ_state_map a) val = AMQ_state_map (A.AMQ_add_internal a val).

    Axiom AMQ_map_query_internalE: forall (a: A.AMQState p) val, A.AMQ_valid a -> A.AMQ_available_capacity a 1 ->
      B.AMQ_query_internal (AMQ_state_map a) val = A.AMQ_query_internal a val.

    Axiom AMQ_map_newE: forall (a: A.AMQState p), 
      B.AMQ_new (AMQ_param_map p)  = AMQ_state_map (A.AMQ_new p).

   End Map.
End AMQMAP.

Module AMQPropertyMap (AmqHash: AMQHASH) (A: AMQ AmqHash) (B: AMQ AmqHash) (Map: AMQMAP AmqHash A B) (Properties: AMQProperties AmqHash B) <:  AMQProperties AmqHash A.
  Module AmqOperations := AMQOperations (AmqHash) (A).
  Module AmqHashProperties := AMQHashProperties AmqHash.
  Module BOp := AMQOperations (AmqHash) (B).

  Section PropertyMap.
    Variable h: AmqHash.AMQHashParams.
    Variable s: A.AMQStateParams.

    Definition AMQ_false_positive_probability  n :=
      Properties.AMQ_false_positive_probability h (Map.AMQ_param_map s) n.

    Lemma AMQ_map_add_multipleE cbf hashes values f
          (Hvalid: A.AMQ_valid cbf) (Hcap: A.AMQ_available_capacity cbf (length values)) :
      \sum_(hshs in [finType of AmqHash.AMQHash h]) \sum_(cbf' in [finType of A.AMQState s])
       ((d[ AmqOperations.AMQ_add_multiple hashes cbf values]) (hshs,cbf') *R*
        (f hshs (Map.AMQ_state_map cbf'))) =
      \sum_(hshs in [finType of AmqHash.AMQHash h]) \sum_(bf' in [finType of B.AMQState (Map.AMQ_param_map s)])
       ((d[ BOp.AMQ_add_multiple hashes (Map.AMQ_state_map cbf) values]) (hshs, bf') *R*
        (f hshs bf')).
    Proof.
      under eq_bigr => hshs' _ do
                             rewrite (@partition_big _ _ _ [finType of (A.AMQState s)] [finType of (B.AMQState _)] _  (@Map.AMQ_state_map s) predT) => //=.
      under eq_bigr => hshs' _ do
                             under eq_bigr => bf _ do
                                                 under eq_bigr => i /eqP Hbi do rewrite Hbi mulRC.
      rewrite exchange_big  [\sum_(a in [finType of AmqHash.AMQHash h]) _]exchange_big; apply eq_bigr => bf _.
      elim: values Hcap  bf f => [|val values IHval] Hcap bf f.
      - {
          apply eq_bigr => hshs' _.
          rewrite (@rsum_pred_demote [finType of A.AMQState s]); under eq_bigr => ? ? do rewrite FDist1.dE xpair_eqE mulRC [_ *R* (_ && _ %R)]mulRC andbC boolR_distr -!mulRA.
          rewrite -rsum_pred_demote big_pred1_eq FDist1.dE xpair_eqE boolR_distr.
          rewrite -mulRA; apply f_equal.
          rewrite [_ *R* f _ _ ]mulRC; apply f_equal.
          apply f_equal => //=.
          by rewrite -eqE eq_sym.
        }
      - {
          apply Logic.eq_sym => //=.
          under (@eq_bigr _ _ _ [finType of AmqHash.AMQHash h]) => hshs' _.
          {
            move: IHval bf f hshs' => //= IHval bf f hshs'.
            rewrite (@FDistBind.dE [finType of (AmqHash.AMQHash h) * (B.AMQState (Map.AMQ_param_map s))]); rewrite rsum_split.
            rewrite (@exchange_big _ _ _ [finType of AmqHash.AMQHash h] [finType of B.AMQState (Map.AMQ_param_map s)]) => //=.

            under (@eq_bigr _ _ _ [finType of B.AMQState (Map.AMQ_param_map s)]) =>  bf' _. {
              suff <-:
                 \sum_(i in [finType of AmqHash.AMQHash h])
                 \sum_(i0 in [finType of _] | Map.AMQ_state_map i0 == bf')
                 (FDistBind.d (d[ AmqHash.AMQHash_hash i val])
                              (fun b : AmqHash.AMQHash h * AmqHash.AMQHashValue =>
                                 d[ let (new_hashes, hash_vec) := b in
                                    ret (new_hashes, B.AMQ_add_internal bf' hash_vec)]) 
                              (hshs', bf) *R*
                  P[ AmqOperations.AMQ_add_multiple hashes cbf values === (i, i0)]) =
            \sum_(i in AmqHash.AMQHash h)
                 (P[ BOp.AMQ_add_multiple hashes (Map.AMQ_state_map cbf) values === (i, bf')] *R*
                  FDistBind.d (d[ AmqHash.AMQHash_hash i val])
                              (fun b : AmqHash.AMQHash h * AmqHash.AMQHashValue =>
                                 d[ let (new_hashes, hash_vec) := b in
                                    ret (new_hashes, B.AMQ_add_internal bf' hash_vec)])
                              (hshs', bf)); first by over.
              have Hcap': A.AMQ_available_capacity cbf (length values); first by eapply A.AMQ_available_capacityW with (n:= (length values).+1) => //=.
            move: (@IHval Hcap'
                        bf' (fun (i: [finType of AmqHash.AMQHash h]) (bf': [finType of B.AMQState (Map.AMQ_param_map s)]) =>
                               FDistBind.d (d[ AmqHash.AMQHash_hash i val])
                                           (fun b : AmqHash.AMQHash h * AmqHash.AMQHashValue =>
                                              d[ let (new_hashes, hash_vec) := b in
                                                 ret (new_hashes, B.AMQ_add_internal bf' hash_vec)]) (hshs',bf) )) => //=.
            move=>-> //=.
            have ->: ((index_enum (AmqHash.AMQHash h))) = (index_enum [finType of AmqHash.AMQHash h]); last by apply f_equal => //=.
              by rewrite index_enum_simpl.

            }
            under eq_bigr =>  bf' _. {
              rewrite exchange_big //=.
              by over.
            }
              by over.
          } 
          move=> //=; clear IHval.
          apply eq_bigr => hshs' _.
          apply Logic.eq_sym; under eq_bigr => ? ? do rewrite mulRC.
          rewrite -big_distrl //= mulRC.
          rewrite [_ *R* f _ _]mulRC; apply f_equal.
          under eq_bigr => ? ? do rewrite FDistBind.dE; rewrite exchange_big //= rsum_split //=.
           apply Logic.eq_sym.
          under eq_bigr => bf' _ do (rewrite (@rsum_pred_demote [finType of _]); under eq_bigr => hshs'' _ do rewrite (@rsum_Rmul_distr_l [finType of _])).
          exchange_big_outwards 1 => //=.
          exchange_big_outwards 2 => //=.
          have ->: ((index_enum (AmqHash.AMQHash h))) = (index_enum [finType of AmqHash.AMQHash h]); first by clear;  rewrite index_enum_simpl //=.
          have ->: ((index_enum (A.AMQState s))) = (index_enum [finType of A.AMQState s]); first by clear;  rewrite index_enum_simpl //=.
          apply eq_bigr => inds' _; apply eq_bigr => cbf' _. rewrite -eqE.
          under eq_bigr do rewrite mulRC [_ *R* (d[ _ ]) _]mulRC -mulRA.
          rewrite -rsum_Rmul_distr_l; apply Logic.eq_sym.
          under eq_bigr do rewrite mulRC.
          rewrite -big_distrl  //= mulRC.
          case Hzr0: (P[ AmqOperations.AMQ_add_multiple hashes cbf values === (inds', cbf')] == 0); first by move/eqP: Hzr0 => ->; rewrite !mul0R //=.
          apply f_equal.
          under eq_bigr do rewrite FDistBind.dE; rewrite exchange_big //=; apply Logic.eq_sym.
          under eq_bigr do rewrite FDistBind.dE big_distrl //=; rewrite exchange_big; apply eq_bigr => [[hshs'' inds'']] _.
          under eq_bigr do rewrite [(d[ _ ]) _ *R* _ ]mulRC mulRC mulRA //=; rewrite -big_distrl //= mulRC; apply Logic.eq_sym.
          under eq_bigr do rewrite [(d[ _ ]) _ *R* _ ]mulRC  ; rewrite -big_distrl //= mulRC; apply f_equal.
          under eq_bigr do rewrite FDist1.dE xpair_eqE andbC boolR_distr//=; rewrite -big_distrl //= mulRC.
          apply Logic.eq_sym.
          under eq_bigr do rewrite FDist1.dE xpair_eqE andbC boolR_distr//= mulRA;
            rewrite -big_distrl //= mulRC; apply f_equal.
          apply Logic.eq_sym.
          rewrite (@rsum_pred_demote [finType of _]); under eq_bigr do rewrite mulRC; rewrite -rsum_pred_demote big_pred1_eq //=.
          rewrite -rsum_pred_demote (big_pred1 (Map.AMQ_state_map cbf')).
          move/Bool.negb_true_iff: Hzr0 => Hzr0; move: Hcap => //= Hcap.
          move: (@AmqOperations.AMQ_add_multiple_properties_preserve h s hashes cbf cbf' values inds' (length values) 1 (eq_refl (length values))  Hvalid);
            rewrite addn1 => Hprop; move: (Hprop Hcap Hzr0); clear Hprop => /andP[ Hvalid' Hcap'].
          by rewrite -eqE Map.AMQ_map_add_internalE //=; first rewrite eq_sym //=.
          by move=> //=.
        }
    Qed.

    Theorem AMQ_no_false_negatives (hashes: AmqHash.AMQHash h)  (amq: A.AMQState s) l x xs:
      uniq (x :: xs) -> length xs == l ->
      A.AMQ_valid amq -> A.AMQ_available_capacity amq l.+1 ->

      AmqHash.AMQHash_hashstate_valid hashes ->
      AmqHash.AMQHash_hashstate_available_capacity hashes l.+1 ->

      all (AmqHash.AMQHash_hashstate_unseen hashes) (x::xs) ->
      (d[ res1 <-$ AmqOperations.AMQ_add amq hashes x;
          let '(hsh1, amq1) := res1 in
          res2 <-$ AmqOperations.AMQ_add_multiple hsh1 amq1 xs;
            let '(hsh2, amq2) := res2 in
            res3 <-$ AmqOperations.AMQ_query amq2 hsh2 x;
              ret (snd res3) ] true) = (1 %R).
    Proof.
      by apply (AmqOperations.AMQ_no_false_negatives).
    Qed.

    Theorem AMQ_false_positives_rate
            (hashes: AmqHash.AMQHash h)  l value (values: seq _):

      length values == l ->

        AmqHash.AMQHash_hashstate_valid hashes ->
        AmqHash.AMQHash_hashstate_available_capacity hashes (l.+1) ->


      all (AmqHash.AMQHash_hashstate_unseen hashes) (value::values) ->
      uniq (value::values) ->
        d[ 
            res1 <-$ AmqOperations.AMQ_query (A.AMQ_new s) hashes value;
              let (hashes1, init_query_res) := res1 in
              res2 <-$ AmqOperations.AMQ_add_multiple hashes1 (A.AMQ_new s) values;
                let (hashes2, amq) := res2 in
                res' <-$ AmqOperations.AMQ_query amq  hashes2 value;
                  ret (res'.2)
          ] true = AMQ_false_positive_probability  l.
      Admitted.
    End PropertyMap.

End AMQPropertyMap.



