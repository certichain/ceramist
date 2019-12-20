From mathcomp.ssreflect
     Require Import ssreflect ssrbool ssrnat eqtype fintype choice ssrfun seq path bigop finfun .
From mathcomp.ssreflect
     Require Import tuple.
From mathcomp
     Require Import path.

From infotheo Require Import
     ssrR Reals_ext logb ssr_ext ssralg_ext bigop_ext Rbigop proba.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

From ProbHash.Utils
     Require Import InvMisc rsum_ext.
From ProbHash.Computation
     Require Import Comp Notationv1.
From ProbHash.Core
     Require Import Hash HashVec FixedList.


Module FakeSpec: HashSpec.
  (* Input type being hashed *)
  Axiom B: finType.
  (* size of hash output and bitvector output *)
  Axiom Hash_size: nat.
End FakeSpec.

Module Hash := Hash (FakeSpec).
Module HashVec := HashVec (FakeSpec).
Import HashVec.

Module Type Tmp.

  Parameter F:Type.
  Parameter f: F -> nat.

  Definition addn3f n := f n + 100.

  Axiom Haddn3f: forall n, addn3f n = 10.
End Tmp.


Module Type AMQHASH.
  Parameter AMQHashKey : finType.
  Parameter AMQHashValue : finType.
  Parameter AMQHashParams: Type.
  Parameter AMQHash : AMQHashParams -> finType.

  Section AMQHash.
    Variable p: AMQHashParams. 
    Parameter AMQHash_probability: AMQHashParams -> Rdefinitions.R.

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

      Axiom AMQHash_hashstate_available_capacityW: forall n m, m < n ->
          AMQHash_hashstate_valid hashstate ->
          AMQHash_hashstate_available_capacity hashstate n ->
          AMQHash_hashstate_available_capacity hashstate m.
      
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
          AMQ_valid amq -> m < n -> AMQ_available_capacity amq n -> AMQ_available_capacity amq m.

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

    Axiom AMQ_no_false_negatives: forall l x xs,
      uniq (x :: xs) -> length xs == l ->
      AMQHash_hashstate_available_capacity hashes l.+1 ->
      all (AMQHash_hashstate_unseen hashes) (x::xs) ->
      (d[ res1 <-$ AMQ_add amq hashes x;
          let '(hsh1, amq1) := res1 in
          res2 <-$ AMQ_add_multiple hsh1 amq1 xs;
            let '(hsh2, amq2) := res2 in
            res3 <-$ AMQ_query amq2 hsh2 x;
              ret (snd res3) ] true) = (1 %R).



    Axiom AMQ_false_positives_rate: forall  l value (values: seq _),
        length values == l -> AMQHash_hashstate_available_capacity hashes (l.+1) ->
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

  Module BOp := AMQOperations (AmqHash) (B).

  Section PropertyMap.
    Variable h: AmqHash.AMQHashParams.
    Variable s: A.AMQStateParams.

    Definition AMQ_false_positive_probability  n :=
      Properties.AMQ_false_positive_probability h (Map.AMQ_param_map s) n.


    Theorem AMQ_no_false_negatives (hashes: AmqHash.AMQHash h)  (amq: A.AMQState s) l x xs:
      uniq (x :: xs) -> length xs == l ->
      AmqHash.AMQHash_hashstate_available_capacity hashes l.+1 ->
      all (AmqHash.AMQHash_hashstate_unseen hashes) (x::xs) ->
      (d[ res1 <-$ AmqOperations.AMQ_add amq hashes x;
          let '(hsh1, amq1) := res1 in
          res2 <-$ AmqOperations.AMQ_add_multiple hsh1 amq1 xs;
            let '(hsh2, amq2) := res2 in
            res3 <-$ AmqOperations.AMQ_query amq2 hsh2 x;
              ret (snd res3) ] true) = (1 %R).
    Proof.
      move=> //=.
    Admitted.
    


    Theorem AMQ_false_positives_rate (hashes: AmqHash.AMQHash h)  l value (values: seq _):
        length values == l -> AmqHash.AMQHash_hashstate_available_capacity hashes (l.+1) ->
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

  Definition cool n := n.+1.
  
End AMQPropertyMap.



Module BloomFilterProperties (AbstractAMQ: AMQ) (AmqHash: AMQHASH): AMQProperties AbstractAMQ AmqHash.
  Module AmqOperations := AMQOperations (AbstractAMQ) (AmqHash).
  Export AmqOperations.

End BloomFilterProperties.

Module BloomFilterDefinitions (Spec: HashSpec).

Module HashVec := (HashVec Spec).
Export HashVec.
