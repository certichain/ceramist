From mathcomp.ssreflect
     Require Import ssreflect ssrbool ssrnat eqtype fintype choice ssrfun seq path bigop finfun .

From mathcomp.ssreflect
     Require Import tuple.

From mathcomp
     Require Import path.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

From BloomFilter
     Require Import Parameters Hash Comp Notationv1 BitVector FixedList.


Section BloomFilter.
  (*
   A fomalization of a bloom filter structure and properties

   *)

  (*
    k - number of hashes
   *)
  Variable k: nat.
  (*
    n - maximum number of hashes supported
   *)
  Variable n: nat.
  Variable Hkgt0: k >0.


  Lemma Hpredkvld: k.-1 < k.
    Proof.
        by  apply InvMisc.ltnn_subS.
    Qed.


  Record BloomFilter := mkBloomFilter {
                            bloomfilter_hashes: k.-tuple (HashState n);
                            bloomfilter_state: BitVector
                          }.

  Definition BloomFilter_prod (bf: BloomFilter) :=
    (bloomfilter_hashes bf, bloomfilter_state bf).
  Definition prod_BloomFilter  pair := let: (hashes, state) := pair in @mkBloomFilter hashes state.

  Lemma bloomfilter_cancel : cancel (BloomFilter_prod) (prod_BloomFilter).
  Proof.
      by case.
  Qed.


  Definition bloomfilter_eqMixin :=
    CanEqMixin bloomfilter_cancel .
  Canonical bloomfilter_eqType  :=
    Eval hnf in EqType BloomFilter  bloomfilter_eqMixin .

  Definition bloomfilter_choiceMixin :=
    CanChoiceMixin bloomfilter_cancel.
  Canonical bloomfilter_choiceType  :=
    Eval hnf in ChoiceType BloomFilter  bloomfilter_choiceMixin.

  Definition bloomfilter_countMixin :=
    CanCountMixin bloomfilter_cancel.
  Canonical bloomfilter_countType :=
    Eval hnf in CountType BloomFilter  bloomfilter_countMixin.

  Definition bloomfilter_finMixin :=
    CanFinMixin bloomfilter_cancel .
  Canonical bloomfilter_finType :=
    Eval hnf in FinType BloomFilter  bloomfilter_finMixin.


  Definition bloomfilter_set_bit (value: 'I_(Hash_size.+1)) bf : BloomFilter :=
    mkBloomFilter
      (bloomfilter_hashes bf)
      (set_tnth (bloomfilter_state bf) true value).

  Definition bloomfilter_get_bit (value: 'I_(Hash_size.+1)) bf : bool :=
      (tnth (bloomfilter_state bf) value).

  Definition bloomfilter_calculate_hash (index: 'I_k) (input: B) (bf: BloomFilter) : Comp [finType of (BloomFilter * 'I_(Hash_size.+1))] :=
    let: hash_state := tnth (bloomfilter_hashes bf) index in
    hash_out <-$ (@hash _ input hash_state);
      let: (new_hash_state, hash_value) := hash_out in
      ret (mkBloomFilter  (set_tnth (bloomfilter_hashes bf) new_hash_state index) (bloomfilter_state bf), hash_value).


  Definition bloomfilter_update_state (index: 'I_k) (hash_result: Comp [finType of (BloomFilter * 'I_(Hash_size.+1))]) : Comp [finType of BloomFilter] :=
    result <-$ hash_result;
      let: (new_bf, hash_index) := result in
      ret (bloomfilter_set_bit hash_index new_bf).
                                  

  Definition bloomfilter_check_state (hash_result: Comp [finType of (BloomFilter * 'I_(Hash_size.+1))]) : Comp [finType of bool] :=
    result <-$ hash_result;
      let: (new_bf, hash_index) := result in
      ret (bloomfilter_get_bit hash_index new_bf).

  Lemma Hltn_leq pos pos' (Hpos: pos < k) (Hpos': pos = pos'.+1) : pos' < k.
      by  move: (Hpos); rewrite {1}Hpos' -{1}(addn1 pos') => /InvMisc.addr_ltn .
    Qed.  


  Fixpoint bloomfilter_add_internal (value: B) (bf: BloomFilter) (pos: nat) (Hpos: pos < k) : Comp [finType of BloomFilter] :=
    (
      match pos as pos' return (pos = pos' -> Comp [finType of BloomFilter]) with
        (* Case 1: pos is 0 *)
      | 0 => (fun Hpos': pos = 0 =>
        (* then update the state and return *)
               (bloomfilter_update_state (Ordinal Hpos) (bloomfilter_calculate_hash (Ordinal Hpos) value bf)))
        (* Case 2: pos is pos.+1 *)
    | pos'.+1 => (fun Hpos': pos = pos'.+1 =>
        (* then update the state*)
            (Bind (bloomfilter_update_state (Ordinal Hpos) (bloomfilter_calculate_hash (Ordinal Hpos) value bf)) 
        (* and recurse on a smaller argument *)
                                (fun new_bf => 
                                       bloomfilter_add_internal value new_bf (Hltn_leq Hpos Hpos')
                                )
                    )
            )
     end
    ) (erefl pos).



  Definition bloomfilter_add (value: B) (bf: BloomFilter) : Comp [finType of BloomFilter] :=
    bloomfilter_add_internal value bf Hpredkvld.



  Fixpoint bloomfilter_query_internal (value : B) (bf : BloomFilter) 
                           (pos : nat) (Hpos : pos < k) {struct pos} :
  Comp [finType of bool] :=
    (
      match pos as pos' return (pos = pos' -> Comp [finType of bool]) with
        (* Case 1: pos is 0 *)
      | 0 => (fun Hpos': pos = 0 =>
        (* then check corresponding bitvector and return *)
               (bloomfilter_check_state (bloomfilter_calculate_hash (Ordinal Hpos) value bf)))
        (* Case 2: pos is pos.+1 *)
    | pos'.+1 => (fun Hpos': pos = pos'.+1 =>
        (* then check the bitvector*)
            (Bind (bloomfilter_calculate_hash (Ordinal Hpos) value bf) 
        (* and if successful recurse on a smaller argument *)
                                (fun updated_state => 
                                    let: (new_bf, hash_index) := updated_state in
                                    match (bloomfilter_get_bit hash_index new_bf) with
                                    true => bloomfilter_query_internal value new_bf (Hltn_leq Hpos Hpos')
                                    | false => ret false

                                    end
                                )
                    )
            )
     end
    ) (erefl pos).

  Definition bloomfilter_query (value: B) (bf: BloomFilter ) : Comp [finType of bool] := bloomfilter_query_internal value bf Hpredkvld.


End BloomFilter.