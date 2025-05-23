/=  sp  /common/stark/prover
/=  emission  /common/schedule
/=  mine  /common/pow
/=  *  /common/zeke
/=  *  /common/zoon
::    tx-engine: this contains all transaction types and logic related to dumbnet.
::
::  the most notable thing about how this library is written are the types.
::  we are experimenting with a namespacing scheme for functions that are
::  primarily about particular types inside of the namespace for that type,
::  as suggested by Ted in urbit/#6881. that is
::
::  ++  list
::    =<  form
::    |%
::    ++  form  |$  [a]  $?(~ [i=a t=$])
::    ++  flop  |*(...)
::    ++  turn  |*(...)
::    ...
::    --
::
::  this file is an experiment to maximize this style for a single module, and then
::  see how well it interfaces with hoon written in more familiar styles.
=>
~%  %dumb-transact  ..stark-engine-jet-hook  ~
|%
+|  %misc-types
::
::  size in bytes. this is not a blockchain constant, its just an alias
::  to make it clear what the atom represents and theres not a better spot
::  for it.
+$  size  @bytes
::
::   $blockchain-constants
::
::  type to hold all the blockchain constants. provided for convenience
::  when using non-default constants.
+$  blockchain-constants
  $+  blockchain-constants
  $~  :*  ::  max block size in bytes
          max-block-size=`size``@`1.000.000
          :: actual number of blocks, not 2017 by counting from 0
          blocks-per-epoch=2.016
          ::  14 days measured in seconds, 1.209.600
          target-epoch-duration=^~(:(mul 14 24 60 60))
          ::  how long to wait before changing candidate block timestamp
          update-candidate-timestamp-interval=~m2
          ::  how far in the future to accept a timestamp on a block
          max-future-timestamp=^~((mul 60 120))
          ::  how many blocks in the past to look at to compute median timestamp from
          ::  which a new block's timestamp must be after to be considered valid
          min-past-blocks=11
          ::TODO determine appropriate genesis target
          genesis-target-atom=^~((div max-tip5-atom:tip5 (bex 2)))
          ::TODO determine a real max-target-atom. BTC uses 32 leading zeroes
          max-target-atom=max-tip5-atom:tip5
          ::  whether or not to check the pow of blocks
          check-pow-flag=&
          ::  minimum range of coinbase timelock
          coinbase-timelock-min=100
          ::  pow puzzle length
          pow-len=pow-len
          ::  how many ways the coinbase may be split
          max-coinbase-split=2
      ==
  $:  max-block-size=size
      blocks-per-epoch=@
      target-epoch-duration=@
      update-candidate-timestamp-interval=@dr
      max-future-timestamp=@
      min-past-blocks=@
      genesis-target-atom=@
      max-target-atom=@
      check-pow-flag=?
      coinbase-timelock-min=@
      pow-len=@
      max-coinbase-split=@
  ==
--
::
::    tx-engine
::
::  contains the tx engine. the default sample for the door is mainnet constants,
::  pass something else in if you need them (and make sure to use the same door
::  for all calls into this library).
~%  %tx-engine  +>  ~
|_  blockchain-constants
+|  %constants
::  one quarter epoch duration - used in target adjustment calculation
++  quarter-ted  ^~((div target-epoch-duration 4))
::  4x epoch duration - used in target adjustment calculation
++  quadruple-ted  ^~((mul target-epoch-duration 4))
++  genesis-target  ^~((chunk:bignum genesis-target-atom))  ::TODO set this
++  max-target  ^~((chunk:bn max-target-atom))
+|  %simple-tx-engine-types
+$  block-commitment  hash
+$  tx-id  hash
+$  coins  @ud  :: the smallest unit, i.e. atoms.
+$  page-number  @ud
++  bn  bignum
+$  page-summary  :: used for status updates
  $:  digest=block-id
      timestamp=@
      epoch-counter=@
      target=bignum:bn
      accumulated-work=bignum:bn
      height=page-number
      parent=block-id
  ==
::
+|  %complex-tx-engine-types
++  btc-hash
  =<  form
  |%
  ++  form
    $+  btc-hash
    [@ux @ux @ux @ux @ux @ux @ux @ux]
  ++  hashable  |=(=form leaf+form)
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
++  block-id
  =<  form
  |%
  ++  form  hash
  ++  to-list  to-list:hash
  --
::  $hash: output of tip:zoon arm
++  hash
  =<  form
  |%
  ++  form
    $+  noun-digest
    [@ux @ux @ux @ux @ux]
  ::
  ++  to-b58  |=(has=form `cord`(crip (en-base58 (digest-to-atom:tip5 has))))
  ++  from-b58  |=(=cord `form`(atom-to-digest:tip5 (de-base58 (trip cord))))
  ++  to-list
    |=  bid=form
    ^-  (list @)
    =+  [a=@ b=@ c=@ d=@ e=@]=bid
    [a b c d e ~]
  --
::
++  schnorr-pubkey
  =<  form
  |%
  +$  form  a-pt:curve:cheetah
  ::
  ++  to-b58  |=(sop=form `cord`(a-pt-to-base58:cheetah sop))
  ++  from-b58  |=(=cord `form`(base58-to-a-pt:cheetah cord))
  ++  to-lock  |=(sop=form (new:lock sop))
  ++  hash  |=(=form (hash-hashable:tip5 leaf+form))
  --
++  schnorr-seckey
  =<  form
  |%
  +$  form  sk:belt-schnorr:cheetah
  ::
  ++  from-atom
    |=  sk=@ux
    ^-  form
    (atom-to-t8:belt-schnorr:cheetah sk)
  ::
  ++  to-atom
    |=  sk=form
    (t8-to-atom:belt-schnorr:cheetah sk)
  --
++  schnorr-signature
  =<  form
  |%
  +$  form
    [chal=chal:belt-schnorr:cheetah sig=sig:belt-schnorr:cheetah]
  ::
  ++  hashable  |=(=form leaf+form)
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::  $signature: multisigs, with a single sig as a degenerate case
++  signature
  =<  form
  |%
  +$  form  (z-map schnorr-pubkey schnorr-signature)
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    ?~  form  leaf+form
    :+  [hash+(hash:schnorr-pubkey p.n.form) (hashable:schnorr-signature q.n.form)]
      $(form l.form)
    $(form r.form)
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $source: commitment to sources of an note
::
::    for an ordinary note, this is a commitment to the notes that spend into a
::    given note. for a coinbase, this is the hash of the previous block (this avoids
::    a hash loop in airwalk)
::
::    so you should be able to walk backwards through the sources of any transaction,
::    and the notes that spent into that, and the notes that spent into those, etc,
::    until you reach coinbase(s) at the end of that walk.
++  source
  =<  form
  |%
  +$  form  [p=^hash is-coinbase=?]
  ::
  ++  from-b58
    |=  [h=@t c=?]
    %*  .  *form
      p  (from-b58:^hash h)
      is-coinbase  c
    ==
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    :-  hash+p.form
    leaf+is-coinbase.form
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $nname: unique note identifier
::
::    first hash is a commitment to the note's .lock and whether or
::    not it has a timelock.
::
::    second hash is a commitment to the note's source and actual
::    timelock
::
::    there are also stubs for pacts, which are currently unimplemented.
::    but they are programs that must return %& in order for the note
::    to be spendable, and are included in the name of the note. right
::    now, pacts are ~ and always return %&.
::
::TODO for dumbnet, this will be [hash hash ~] but eventually we want (list hash)
::which should be thought of as something like a top level domain, subdomain, etc.
++  nname
  =<  form
  ~%  %nname  ..nname  ~
  |%
  +$  form  [^hash ^hash ~]
  ::
  ++  new
    =<  default
    |%
    ++  default
      |=  [owners=lock =source =timelock]
      ^-  form
      =/  first-name
        %-  hash-hashable:tip5
        :*  leaf+&                  :: outcome of first pact
            leaf+!=(~ timelock)     :: does it have a timelock?
            hash+(hash:lock owners)  :: owners of note
            leaf+~                  :: first pact
        ==
      =/  last-name
        %-  hash-hashable:tip5
        :*  leaf+&                          :: outcome of second pact
            (hashable:^source source)       :: source of note
            hash+(hash:^timelock timelock)  :: timelock of note
            leaf+~                          :: second pact
        ==
      [first-name last-name ~]
    ::
    ++  simple
      |=  [owners=lock =source]
      ^-  form
      (new owners source *timelock)
    --
  ::
  ++  from-b58
    |=  [first=@t last=@t]
    ^-  form
    :~  (from-b58:^hash first)
        (from-b58:^hash last)
    ==
  ::
  ++  to-b58
    |=  nom=form
    ^-  [first=@t last=@t]
    :-  (to-b58:^hash -.nom)
    (to-b58:^hash +<.nom)
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    [[%hash -.form] [%hash +<.form] [%leaf +>.form]]
  ::
  ++  hash
    ~/  %hash
    |=  =form
    (hash-hashable:tip5 (hashable form))
  --  ::+name
::
::  $page: a block
::
::    .digest: block hash, hash of +.page
::    .pow: stark seeded by hash of +>.page
::    .parent: .digest of parent block
::    .tx-ids: ids of txs included in block
::    .coinbase: $coinbase-split
::    .timestamp:
::      time from (arbitrary time) in seconds. not exact.
::      practically, it will never exceed the goldilocks prime.
::    .epoch-counter: how many blocks in current epoch (0 to 2015)
::    .target: target for current epoch
::    .accumulated-work: sum of work over the chain up to this point
::    .height: page number of block
::    .msg: optional message as a (list belt)
::
::    if you're wondering where the nonce is, its in the %puzzle
::    of a $proof.
::
::    fields for the commitment are ordered from most frequently updated
::    to least frequently updated for merkleizing efficiency - except for
::    .parent, in order to allow for PoW-chain proofs to be as small as
::    possible.
++  page
  =<  form
  |%
  +$  form
    $+  page
    $:  digest=block-id
        :: everything below this is what is hashed for the digest: +.page
        pow=$+(pow (unit proof:sp))
        :: everything below this is what is hashed for the block commitment: +>.page
        parent=block-id   ::TODO sam's comment on why this is here
        tx-ids=(z-set tx-id)
        coinbase=coinbase-split
        timestamp=@
        epoch-counter=@ud
        target=bignum:bn
        accumulated-work=bignum:bn
        height=page-number
        msg=page-msg
    ==
  ::
  ::  +new: builds a minimally populated page given a parent page and key
  ::
  ::    when a $page is built with +new, it is the minimal amount of state
  ::    needed to call +block-commitment on it and then pass that commit
  ::    to the miner to start mining on an empty block.
  ::
  ::    genesis block should be built with new-genesis
  ::
  ::    while we store target and accumulated-work as bignums, we
  ::    do not yet employ bignum arithmetic
  ++  new
    |=  [par=form now=@da target-bn=bignum:bn shares=(z-map lock @)]
    ^-  form
    ::  at launch, we do not allow coinbases to be split more than two ways
    ?>  (lte (lent ~(key z-by shares)) max-coinbase-split)
    =/  accumulated-work=bignum:bn
      %-  chunk:bn
      (add (merge:bn (compute-work target-bn)) (merge:bn accumulated-work.par))
    =/  epoch-counter=@
      ?:  =(+(epoch-counter.par) blocks-per-epoch)  0
      +(epoch-counter.par)
    =/  height=@  +(height.par)
    %*  .  *form
      ::minimum information needed to generate a valid block commitment, so
      ::that a miner can start mining on an empty block.
      height                 height
      parent                 digest.par
      timestamp              (time-in-secs now)
      epoch-counter          epoch-counter
      target                 target-bn
      accumulated-work       accumulated-work
      coinbase               %+  new:coinbase-split
                               (emission-calc:coinbase height)
                             shares
    ==
  ::
  ::  +new-genesis: builds a minimally populated $page suitable to mine as genesis block.
  ::
  ++  new-genesis
    |=  [tem=genesis-template timestamp=@da]
    ^-  form
    ::  explicitly writing out the bunts is unnecessary, but we want to make it clear
    ::  that each of these choices was deliberate rather than unfinished
    =/  pag=form
      %*  .  *form
        pow                    *(unit proof:sp)
        tx-ids                 *(z-set tx-id)
        timestamp              (time-in-secs timestamp)
        epoch-counter          *@
        target                 genesis-target
        accumulated-work       (compute-work genesis-target)
        coinbase               *(z-map lock @)  :: ensure coinbase is unspendable
        height                 *page-number
        parent                 (hash:btc-hash btc-hash.tem)
        msg                    message.tem
      ==
    pag(digest (compute-digest pag))
  ::
  ::
  ::  +block-commitment: hash commitment of block contents for miner
  ::
  ::    this hashes everything after the .pow
  ++  hashable-block-commitment
    |=  =form
    ^-  hashable:tip5
    |^
    :*  hash+parent.form
        hash+(hash-hashable:tip5 (hashable-tx-ids tx-ids.form))
        hash+(hash:coinbase-split coinbase.form)
        leaf+timestamp.form
        leaf+epoch-counter.form
        leaf+target.form
        leaf+accumulated-work.form
        leaf+height.form
        leaf+msg.form
    ==
    ::
    ++  hashable-tx-ids
      |=  tx-ids=(z-set tx-id)
      ^-  hashable:tip5
      ?~  tx-ids  leaf+tx-ids
      :+  hash+n.tx-ids
        $(tx-ids l.tx-ids)
      $(tx-ids r.tx-ids)
    --
  ::
  ++  block-commitment
    |=  =form
    (hash-hashable:tip5 (hashable-block-commitment form))
  ::
  ++  check-digest
    |=  pag=form
    ^-  ?
    =(digest.pag (compute-digest pag))
  ::
  ::  Hash pow with hash-proof and hash the rest of the page.
  ++  compute-digest
    |=  pag=form
    ^-  block-id
    %-  hash-hashable:tip5
    :-  ?~  pow.pag  leaf+~
        [leaf+~ hash+(hash-proof u.pow.pag)]
    (hashable-block-commitment pag)
  ::
  ::  +time-in-secs: returns @da in seconds.
  ++  time-in-secs
    |=  now=@da
    ^-  @
    =/  tar=tarp  (yell now)
    ;:  add
      (mul d.tar day:yo) :: seconds in a day
      (mul h.tar hor:yo) :: seconds in an hour
      (mul m.tar mit:yo) :: seconds in a minute
      s.tar              :: seconds in a second
    ==
  ::
  ::  +compute-size:
  ::
  ::    this is equal to the size of the jammed $page plus the size of all the
  ::    transactions (which are not inlined in the block, so must also be passed
  ::    in). we pass in raw-txs instead of txs because this is utilized when building
  ::    candidate blocks, and so the txs will not be available in the $consensus-state.
  ++  compute-size
    |=  [pag=form raw-txs=(z-map tx-id raw-tx)]
    ^-  size
    %+  add
      :: size of page in number of bytes. note that we do not include the digest
      :: or powork.
      (div (compute-size-belt-noun `*`+>.pag) 8)
    %+  roll  ~(tap z-in tx-ids.pag)
    |=  [id=tx-id sum-sizes=size]
    %+  add  sum-sizes
    (compute-size:raw-tx (~(got z-by raw-txs) id))
  ::
  ++  to-local-page
    |=  pag=form
    ^-  local-page
    pag(pow (bind pow.pag |=(p=proof:sp (jam p))))
  ::
  ::  +compute-work: how much heaviness a block contribute to .accumulated-work
  ::
  ::    see GetBlockProof in https://github.com/bitcoin/bitcoin/blob/master/src/chain.cpp
  ::    last changed in commit 306ccd4927a2efe325c8d84be1bdb79edeb29b04 for the source
  ::    of this formula.
  ::
  ::    while we store target and work as bignums, we do not yet utilize bignum arithmetic.
  ++  compute-work
    |=  target-bn=bignum:bn
    ^-  bignum:bn
    =/  target-atom=@  (merge:bn target-bn)
    (chunk:bn (div max-target-atom +(target-atom)))
  ::
  ++  to-page-summary
    |=  pag=form
    ^-  page-summary
    :*  digest.pag
        timestamp.pag
        epoch-counter.pag
        target.pag
        accumulated-work.pag
        height.pag
        parent.pag
    ==
  ::
  ::  +compare-heaviness: %.y if first page is heavier, %.n otherwise
  ::
  ::    second arg is $local-page since that is always how this is done right now.
  ++  compare-heaviness
    |=  [pag1=form pag2=local-page]
    ^-  ?
    %+  gth  (merge:bn accumulated-work.pag1)
    (merge:bn accumulated-work.pag2)
  --
::
::  A locally-stored page. The only difference from +page is that pow is jammed
::  to save space. Must be converted into a +page (ie cue the pow) for hashing.
++  local-page
  =<  form
  |%
  +$  form
    $+  local-page
    $:  digest=block-id
        pow=$+(pow (unit @))
        parent=block-id
        tx-ids=(z-set tx-id)
        coinbase=coinbase-split
        timestamp=@
        epoch-counter=@ud
        target=bignum:bn
        accumulated-work=bignum:bn
        height=page-number
        msg=page-msg
    ==
  ::
  ++  to-page
    |=  lp=form
    ^-  page
    lp(pow (biff pow.lp |=(j=@ ((soft proof:sp) (cue j)))))
  --
::
::  +page-msg: (list belt) that enforces that each elt is a belt
++  page-msg
  =<  form
  |%
  +$  form
    $|  (list belt)
    |=  tap=(list belt)
    (levy tap |=(t=@ (based t)))
  ::
  ++  new  |=(msg=cord (form (rip-correct 5 msg)))
  ::
  ++  hash
    |=  =form
    ^-  ^hash
    (hash-hashable:tip5 leaf+form)
  --
::
::  +genesis-seal: information to identify the correct genesis block
::
::    before nockchain is launched, a bitcoin block height and message
::    hash will be publicly released. the height is the height at which
::    nockchain will be launched. the "correct" genesis block will
::    be identified by matching the message hash with the hash of the
::    message in the genesis block, and then confirming that the parent
::    of the genesis block is a hash built from the message, the height,
::    and the hash of the bitcoin block at that height.
::
::    the height and message hash are known as the "genesis seal".
::
++  genesis-seal
  =<  form
  |%
  +$  form
    %-  unit
    $:  block-height=belt
        msg-hash=hash
    ==
  ::
  ++  new
    |=  [height=page-number msg-hash=@t]
    ^-  form
    (some [height (from-b58:hash msg-hash)])
  --
::
::  $genesis-template:
::
::    supplies the block hash and height of the Bitcoin block which must be
::    used for the genesis block. note that the hash is a SHA256, while we
::    want a 5-tuple $noun-digest. we call +new in this core with the raw
::    atom representing the SHA256 hash, which then converts it into a 5-tuple.
::
++  genesis-template
  =<  form
  |%
  +$  form
    $:  =btc-hash
        block-height=@       :: interpreted as a belt
        message=page-msg
    ==
  ::
  ++  new
    |=  [=btc-hash block-height=@ message=cord]
    ^-  form
    =/  split-msg  (new:page-msg message)
    [btc-hash block-height split-msg]
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    [leaf+btc-hash.form leaf+block-height.form hash+(hash:page-msg message.form)]
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
++  inputs
  =<  form
  ~%  %inputs  ..inputs  ~
  |%
  +$  form  (z-map nname input)
  ::
  ++  new
    =<  default
    |%
    ++  default
      |=  =input
      ^-  form
      (~(put z-by *form) [name.note.input input])
    ::
    ++  multi
      |=  ips=(list input)
      ^-  form
      %-  ~(gas z-by *form)
      %+  turn  ips
      |=  inp=input
      [name.note.inp inp]
    --
  ::
  ++  names
    |=  ips=form
    ^-  (z-set nname)
    ~(key z-by ips)
  ::
  ++  roll-fees
    |=  ips=form
    ^-  coins
    %+  roll  ~(val z-by ips)
    |=  [inp=input fees=coins]
    (add fee.spend.inp fees)
  ::
  ++  roll-timelocks
    |=  ips=form
    ^-  timelock-range
    %+  roll  ~(val z-by ips)
    |=  [ip=input range=timelock-range]
    %+  merge:timelock-range
      range
    (fix-absolute:timelock timelock.note.ip origin-page.note.ip)
  ::
  ::  +validate: calls validate:input on each input, and checks key/value
  ++  validate
    ~/  %validate
    |=  ips=form
    ^-  ?
    ?:  =(ips *form)  %.n  :: tx with no inputs are not allowed.
    %+  levy  ~(tap z-by ips)
    |=  [name=nname inp=input]
    ?&  (validate:input inp)
        =(name name.note.inp)
    ==
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    ?~  form  leaf+form
    :+  [(hashable:nname p.n.form) (hashable:input q.n.form)]
      $(form l.form)
    $(form r.form)
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
++  outputs
  =<  form
  ~%  %outputs  ..outputs  ~
  |%
  +$  form  (z-map lock output)   :: lock is the recipient
  ::
  ++  new
    ~/  %new
    |=  [ips=inputs new-page-number=page-number]
    ^-  form
    ?:  =(ips *inputs)  !!  :: zero utxo tx not allowed
    =|  children=form
    =/  inputs=(list input)  ~(val z-by ips)
    |-
    ?~  inputs
      (birth-children children new-page-number)
    ?.  (validate:input i.inputs)
      ~&  >>>
          :*  %failed-spend-validate
              "note name "
              name.note.i.inputs
              " signature "
              signature.spend.i.inputs
          ==
      !!
    =/  seed-list=(list seed)  ~(tap z-in seeds.spend.i.inputs)
    |-
    ?~  seed-list
      ^$(inputs t.inputs)
    =.  children  (add-seed children i.seed-list)
    $(seed-list t.seed-list)
  ::
  ::  +validate: calls validate:output on each output, and checks key/value
  ++  validate
    ~/  %validate
    |=  ops=form
    ^-  ?
    %+  levy  ~(tap z-by ops)
    |=  [loc=lock out=output]
    ?&  (validate:output out)
        =(loc lock.note.out)
    ==
  ::
  ::  +add-seed: adds seed to $outputs of a tx
  ::
  ::    this iterates over the children and checks to see if any of them
  ::    have the same $lock as the seed. if so, add the seed to that child.
  ::    otherwise, create a new child that contains the seed.
  ++  add-seed
    |=  [children=form sed=seed]
    ^+  children
    ?:  (~(has z-by children) recipient.sed)
      =/  child=output  (~(got z-by children) recipient.sed)
      ?:  (~(has z-in seeds.child) sed)
        ~&  >>>  "can't add same seed to an output more than once"
        !!
      =.  seeds.child  (~(put z-in seeds.child) sed)
      (~(put z-by children) recipient.sed child)
    =/  child=output
      %*  .  *output
        seeds  (~(put z-in *seeds) sed)
      ==
    (~(put z-by children) recipient.sed child)
  ::
  ++  birth-children
    |=  [children=form new-page-number=page-number]
    ^+  children
    |^
    =.  children
      %-  ~(run z-by children)
      |=  child=output
      =.  origin-page.note.child  new-page-number
      ::  to avoid a hash-loop, we hash the tails of the seeds
      =.  source.note.child  (compute-source:output child)
      =.  child
        %+  roll  ~(tap z-in seeds.child)
        |=  [=seed chi=_child]
        =?  timelock.note.chi  !=(~ timelock-intent.seed)
          (reconcile timelock.note.child timelock-intent.seed)
        =.  assets.note.chi  (add gift.seed assets.note.chi)
        =.  lock.note.chi  recipient.seed
        chi
      ::
      =.  name.note.child
        %-  new:nname
        :*  lock.note.child
            source.note.child
            timelock.note.child
        ==
      child
    children
    ::
    ++  reconcile
      |=  [a=timelock b=timelock-intent]
      ^-  timelock
      ?~  b  a
      =/  b-timelock=timelock  (convert-from-intent:timelock b)
      ?~  a  b-timelock
      ?:(=(a b-timelock) a !!)
    -- ::+birth-children
  --  ::+outputs
::
::  +raw-tx: a tx as found in the mempool, i.e. the wire format of a tx.
::
::    in order for a raw-tx to grow up to become a tx, it needs to be included in
::    a block. some of the data of a tx cannot be known until we know which block
::    it is in. a raw-tx is all the data we can know about a transaction without
::    knowing which block it is in. when a miner reads a raw-tx from the mempool,
::    it should first run validate:raw-tx on it to check that the inputs are signed.
::    then the miner can begin deciding how
::TODO we might want an unsigned version of this as well
++  raw-tx
  =<  form
  ~%  %raw-tx  ..raw-tx  ~
  |%
  +$  form
    $:  id=tx-id  :: hash of +.raw-tx
        =inputs
        ::    the "union" of the ranges of valid page-numbers
        ::    in which all inputs of the tx are able to spend,
        ::    as enforced by their timelocks
        =timelock-range
        ::    the sum of all fees paid by all inputs
        total-fees=coins
    ==
  ++  new
    =<  default
    ~%  %new  ..new  ~
    |%
    ++  default
      ~/  %default
      |=  ips=inputs
      ^-  form
      =/  raw-tx=form
        %*  .  *form
          inputs          ips
          total-fees      (roll-fees:inputs ips)
          timelock-range  (roll-timelocks:inputs ips)
        ==
      =.  raw-tx  raw-tx(id (compute-id raw-tx))
      ?>  (validate raw-tx)
      raw-tx
    ::  +simple-from-note: send all assets from note to recipient
    ++  simple-from-note
      =<  default
      |%
      ++  default
        |=  [recipient=lock not=nnote sk=schnorr-seckey]
        ^-  form
        %-  new
        %-  new:inputs
        %-  simple-from-note:new:input
        :+  recipient
          not
        sk
      ::  +with-refund: send all assets from note to recipient, remainder to owner
      ++  with-refund
        |=  [recipient=lock gift=coins fees=coins not=nnote sk=schnorr-seckey]
        ^-  form
        %-  new
        %-  new:inputs
        %-  with-refund:simple-from-note:new:input
        :*  recipient
            gift
            fees
            not
            sk
        ==
      --
    --
  ::
  ++  compute-id
    |=  raw=form
    ^-  tx-id
    %-  hash-hashable:tip5
    :+  (hashable:inputs inputs.raw)
      (hashable:timelock-range timelock-range.raw)
    leaf+total-fees.raw
  ::
  ++  validate
    ~/  %validate
    |=  raw=form
    ^-  ?
    =/  check-inputs  (validate:inputs inputs.raw)
    =/  check-fees  =(total-fees.raw (roll-fees:inputs inputs.raw))
    =/  check-timelock  =(timelock-range.raw (roll-timelocks:inputs inputs.raw))
    =/  check-id  =(id.raw (compute-id raw))
    :: %-  %-  slog
    ::     :~  leaf+"validate-raw-tx"
    ::         leaf+"inputs: {<check-inputs>}"
    ::         leaf+"fees: {<check-fees>}"
    ::         leaf+"timelock: {<check-timelock>}"
    ::         leaf+"id: {<check-id>}"
    ::     ==
    ?&  check-inputs
        check-fees
        check-timelock
        check-id
    ==
  ::
  ++  inputs-names
    |=  raw=form
    ^-  (z-set nname)
    (names:inputs inputs.raw)
  ::
  ::  +compute-size: returns size in number of bytes
  ++  compute-size
    |=  raw=form
    ^-  size
    (div (compute-size-belt-noun `*`raw) 8)
  --
::
::  $tx: once a raw-tx is being included in a block, it becomes a tx
++  tx
  =<  form
  ~%  %tx  ..tx  ~
  |%
  +$  form
    $:  [raw-tx]         :: this makes it so the head of a tx is a raw-tx
        total-size=size  :: the size of the raw-tx
        =outputs
    ==
  ::
  ++  new
    ~/  %new
    |=  [raw=raw-tx new-page-number=page-number]
    ^-  form
    =/  ops=outputs
      (new:outputs inputs.raw new-page-number)
    %*  .  *form
      id              id.raw
      inputs          inputs.raw
      timelock-range  timelock-range.raw
      total-fees      total-fees.raw
      outputs         ops
      total-size      (compute-size:raw-tx raw)
    ==
  ::
  ++  validate
    ~/  %validate
    |=  [tx=form new-page-number=page-number]
    ^-  ?
    ?&  (validate:raw-tx -.tx)  :: inputs, total-fees, timelock-range, id
        (validate:outputs outputs.tx)
        =(total-size.tx (compute-size tx))
    ==
  ::
  ++  compute-size
    |=  tx=form
    ^-  size
    (compute-size:raw-tx -.tx)
  -- ::+tx
::
::  $timelock-intent: enforces $timelocks in output notes from $seeds
::
::    the difference between $timelock and $timelock-intent is that $timelock-intent
::    permits the values ~ and [~ ~ ~] while $timelock does not permit [~ ~ ~].
::    the reason for this is that a non-null timelock intent forces the output
::    note to have this timelock. so a ~ means it does not enforce any timelock
::    restriction on the output note, while [~ ~ ~] means that the output note
::    must have a timelock of ~.
++  timelock-intent
  =<  form
  ~%  %timelock-intent  ..timelock-intent  ~
  |%
  +$  form
    %-  unit  ::  a value of ~ indicates "no intent"
    $:  absolute=timelock-range  ::  a range of absolute page-numbers
        ::
        ::    a range of relative diffs between the page-number of the note
        ::    and the range of absolute page-numbers in which the note may spend
        relative=timelock-range
    ==
  ::
  ++  hashable
    ~/  %hashable
    |=  =form
    ^-  hashable:tip5
    ?~  form  leaf+~
    :+  leaf+~
      (hashable:timelock-range absolute.u.form)
    (hashable:timelock-range relative.u.form)
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $timelock: an absolute and relative range of page numbers this note may be spent
++  timelock
  =<  form
  ~%  %timelock  ..timelock  ~
  |%
  ::  A timelock, in terms of values, is a $timelock-intent that does not permit [~ ~ ~]
  +$  form  $|(timelock-intent |=(timelock-intent !=(+< [~ ~ ~])))
  ::
  ++  convert-from-intent
    |=  int=timelock-intent
    ^-  form
    ?:  =(int [~ ~ ~])  *form
    int
  ::
  ::  +fix-absolute: produce absolute timelock from relative timelock and page number
  ++  fix-absolute
    |=  [til=form page=page-number]
    ^-  timelock-range
    ?~  til  *timelock-range
    =/  add-page  |=(a=page-number (add a page))
    =/  absolutification=timelock-range
      ?:  =(*timelock-range relative.u.til)  *timelock-range
      =/  min=(unit page-number)
        (bind min.relative.u.til add-page)
      =/  max=(unit page-number)
        (bind max.relative.u.til add-page)
      (new:timelock-range [min max])
    (merge:timelock-range absolutification absolute.u.til)
  ::
  ++  hash
    ~/  %hash
    |=  =form
    (hash-hashable:tip5 (hashable:timelock-intent form))
  --
    ::
::  $timelock-range: unit range of pages
::
::    the union of all valid ranges in which all inputs of a tx may spend
::    given their timelocks. for the dumbnet, we only permit at most one utxo
::    with a non-null timelock-range per transaction.
++  timelock-range
  =<  form
  |%
  +$  form  [min=(unit page-number) max=(unit page-number)]
  ::
  ::  +new: constructor for $timelock-range
  ++  new
    |=  [min=(unit page-number) max=(unit page-number)]
    ^-  form
    [min max]
  ::
  ::  +check: check that a $page-number is in a $timelock-range
  ++  check
    |=  [tir=form new-page-number=page-number]
    ^-  ?
    ?:  =(tir *form)  %.y
    :: TODO normalize timelock range
    ::=/  min  (fall min 0)
    ::=/  max  (fall max 0)
    =/  min-ok=?
      ?~  min.tir  %.y
      (gte new-page-number u.min.tir)
    =/  max-ok=?
      ?~  max.tir  %.y
      (lte new-page-number u.max.tir)
    &(min-ok max-ok)
  ::
  ++  merge
    |=  [a=form b=form]
    ^-  form
    ?:  =(a *form)
      ?:  =(b *form)
        *form
      b
    ?:  =(b *form)
      a
    =/  min=(unit page-number)
      ?~  min.a
        ?~  min.b
          *(unit page-number)
        min.b
      ?~  min.b
        min.a
      (some (max u.min.a u.min.b))
    =/  max=(unit page-number)
      ?~  max.a
        ?~  max.b
          *(unit page-number)
        max.b
      ?~  max.b
        max.a
      (some (^min u.max.a u.max.b))
    (new [min max])
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    :-  ?~(min.form %leaf^~ [%leaf^~ leaf+u.min.form])
    ?~(max.form %leaf^~ [%leaf^~ leaf+u.max.form])
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $lock: m-of-n signatures needed to spend a note
::
::    m (the number of sigs needed) and n (the number of possible signers)
::    must both fit in an 8-bit number, and not be 0. so 1 <= n,m <= 255. While
::    a lock may only be "unlocked" if m =<n, we do permit constructing m>n
::    with an issued warning, since this may happen when constructing a
::    transaction piece-by-piece.
++  lock
  =<  form
  ~%  %lock  ..lock  ~
  |%
  +$  form
    $~  [m=1 pubkeys=*(z-set schnorr-pubkey)]
    [m=@udD pubkeys=(z-set schnorr-pubkey)]
  ::
  ++  new
    =<  default
    |%
    ++  default
      |=  key=schnorr-pubkey
      %*  .  *form
        m  1
        pubkeys  (~(put z-in *(z-set schnorr-pubkey)) key)
      ==
    ::
    ::  +m-of-n: m signers required of n=#keys.
    ++  m-of-n
      |=  [m=@ud keys=(z-set schnorr-pubkey)]
      =/  n=@  ~(wyt z-in keys)
      ?>  ?&  (lte m 255)
              (lte n 255)
              !=(m 0)                                  :: 0-sigs not allowed
              !=(n 0)                                  :: need at least 1 signer
          ==
      ~?  >>>  (lth n m)
          """
          warning: lock requires more signatures {(scow %ud m)} than there
          are in .pubkeys: {(scow %ud n)}
          """
      %*  .  *form
        m  m
        pubkeys  keys
      ==
    --
  ::
  ::  +join: union of several $locks
  ++  join
    |=  [m=@udD locks=(list form)]
    ^-  form
    =/  new-keys=(z-set schnorr-pubkey)
      %+  roll  locks
      |=  [loc=form keys=(z-set schnorr-pubkey)]
      (~(uni z-in keys) pubkeys.loc)
    (m-of-n:new m new-keys)
  ::
  ++  set-m
    |=  [lock=form new-m=@ud]
    ^+  lock
    =/  n=@  ~(wyt z-in pubkeys.lock)
    ?>  ?&  (lte new-m 255)
            !=(new-m 0)
        ==
    ~?  >>>  (lth n new-m)
        """
        warning: lock requires more signatures {(scow %ud new-m)} than there
        are in .pubkeys: {(scow %ud n)}
        """
    lock(m new-m)
  ::
  ++  signers
    |%
    ++  add
      =<  default
      |%
      ++  default
        |=  [lock=form new-key=schnorr-pubkey]
        ^+  lock
        ?:  (~(has z-in pubkeys.lock) new-key)
          ~&  >>>  "signer {<new-key>} already exists in lock"
          lock
        =/  new-keys=(z-set schnorr-pubkey)
          (~(put z-in pubkeys.lock) new-key)
        ?>  (lte ~(wyt z-in new-keys) 255)
        %_  lock
          pubkeys  new-keys
        ==
      ++  multi
        |=  [lock=form new-keys=(z-set schnorr-pubkey)]
        ^+  lock
        %-  ~(rep z-in new-keys)
        |=  [new-key=schnorr-pubkey new-lock=_lock]
        (default new-lock new-key)
      --
    ::
    ++  remove
      =<  default
      |%
      ++  default
        |=  [lock=form no-key=schnorr-pubkey]
        ^+  lock
        ?.  (~(has z-in pubkeys.lock) no-key)
          ~&  >>>  "key {<no-key>} does not exist in lock"
          lock
        =/  new-keys=(z-set schnorr-pubkey)
          (~(del z-in pubkeys.lock) no-key)
        =/  num-keys=@  ~(wyt z-in new-keys)
        ~?  >>>  (lth num-keys m.lock)
          """
          warning: lock requires more signatures {(scow %ud m.lock)} than there
          are in .pubkeys: {(scow %ud num-keys)}
          """
        lock(pubkeys new-keys)
      ::
      ++  multi
        |=  [lock=form no-keys=(z-set schnorr-pubkey)]
        ^+  lock
        %-  ~(rep z-in no-keys)
        |=  [no-key=schnorr-pubkey new-lock=_lock]
        (default new-lock no-key)
      --
    --
  ::
  ++  validate
    |=  lock=form
    ^-  ?
    =/  num-keys=@  ~(wyt z-in pubkeys.lock)
    ?&  (lte m.lock 255)
        !=(m.lock 0)
        (lte num-keys 255)
        !=(num-keys 0)
    ==
  ::
  ++  from-b58
    |=  [m=@ pks=(list @t)]
    ^-  form
    %+  m-of-n:new  m
    %-  ~(gas z-in *(z-set schnorr-pubkey))
    %+  turn  pks
    |=  pk=@t
    (from-b58:schnorr-pubkey pk)
  ++  to-b58
    |=  loc=form
    ^-  [m=@udD pks=(list @t)]
    :-  m.loc
    (turn ~(tap z-in pubkeys.loc) to-b58:schnorr-pubkey)
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    |^
    [leaf+m.form (hashable-pubkeys pubkeys.form)]
    ::
    ++  hashable-pubkeys
      |=  pubkeys=(z-set schnorr-pubkey)
      ^-  hashable:tip5
      ?~  pubkeys  leaf+pubkeys
      :+  hash+(hash:schnorr-pubkey n.pubkeys)
        $(pubkeys l.pubkeys)
      $(pubkeys r.pubkeys)
    --
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $nnote: Nockchain note. A UTXO.
++  nnote
  =<  form
  ~%  %nnote  ..nnote  ~
  |%
  +$  form
    $:  $:  version=%0  ::  utxo version number
          ::    the page number in which the note was added to the balance.
          ::NOTE while for dumbnet this could be block-id instead, and that
          ::would simplify some code, for airwalk this would lead to a hashloop
          origin-page=page-number
          ::    a note with a null timelock has no page-number restrictions
          ::    on when it may be spent
          =timelock
      ==
    ::
      name=nname
      =lock
      =source
      assets=coins
    ==
  ::
  ++  hashable
    ~/  %hashable
    |=  =form
    ^-  hashable:tip5
    :-  :+  leaf+version.form
          leaf+origin-page.form
        hash+(hash:timelock timelock.form)
    :^    hash+(hash:nname name.form)
        hash+(hash:lock lock.form)
      hash+(hash:source source.form)
    leaf+assets.form
  ::
  ++  hash
    ~/  %hash
    |=  =form
    %-  hash-hashable:tip5
    (hashable form)
  --
::
::  $coinbase: mining reward. special kind of note
::
++  coinbase
  =<  form
  |%
  ++  form
    $:  $~  %*  .  *nnote
              timelock            coinbase-timelock
              is-coinbase.source  %.y
            ==
        $|  nnote
        |=  note=nnote
        ::  mining reward may only be spent 100 blocks after confirmation
        ?&  =(coinbase-timelock timelock.note)
            is-coinbase.source.note
        ==
        ::  these aren't the only conditions needed for a coinbase. we also
        ::  need that p.source is the hash of the previous block.
    ==
  ::
  ::  +new: make coinbase for page. not for genesis.
  ++  new
    |=  [pag=page =lock]
    =/  reward=coins  (~(got z-by coinbase.pag) lock)
    ^-  form
    %*  .  *nnote
      assets       reward
      lock         lock
      timelock     coinbase-timelock
      origin-page  height.pag
      name         (name-from-parent-hash lock parent.pag)
    ::
      ::  this uses the ID of the parent block to avoid a hashloop in airwalk
      source       [parent.pag %.y]
    ==
  ::
  ::  +name-from-parent-hash: the name of a coinbase with given owner and parent block.
  ++  name-from-parent-hash
    |=  [owners=lock parent-hash=hash]
    ^-  nname
    (new:nname owners [parent-hash %.y] coinbase-timelock)
  ::
  ++  coinbase-timelock
    ^-  timelock
    (some [*timelock-range (new:timelock-range [(some coinbase-timelock-min) ~])])
  ::
  ++  emission-calc
    |=  =page-number
    ^-  coins
    (schedule:emission `@`page-number)
  --
::
::  $coinbase-split: total number of nicks split between mining pubkeys
::
::    despite also being a (z-map lock @), this is not the same thing as .shares
::    from the mining state. this is the actual number of coins split between the
::    locks, while .shares is a proportional split used to calculate the actual
::    number.
++  coinbase-split
  =<  form
  |%
  +$  form  (z-map lock coins)
  ::
  ++  new
    |=  [assets=coins shares=(z-map lock @)]
    ^-  form
    =/  locks=(list lock)  ~(tap z-in ~(key z-by shares))
    ?:  =(1 (lent locks))
      ::  if there is only one pubkey, there is no need to compute a split.
      (~(put z-by *form) (snag 0 locks) assets)
    ::
    =/  split=(list [=lock share=@ =coins])
      %+  turn  ~(tap z-by shares)
      |=([=lock s=@] [lock s 0])
    ::
    =|  recursion-depth=@
    =/  remaining-coins=coins  assets
    =/  total-shares=@
      %+  roll  split
      |=  [[=lock share=@ =coins] sum=@]
      (add share sum)
    |-
    ?:  =(0 remaining-coins)
      (~(gas z-by *form) (turn split |=([l=lock s=@ t=coins] [l t])))
    ?:  (gth recursion-depth 2)
      ::  we only allow two rounds of recursion to shave microseconds
      ::  if any coins are left, we distribute them to the first share
      =/  final-split=(list [lock coins])
        (turn split |=([l=lock s=@ t=coins] [l t]))
      =/  first=[l=lock c=coins]  (snag 0 final-split)
      =.  c.first  (add c.first remaining-coins)
      =.  final-split  [first (slag 1 final-split)]
      (~(gas z-by *form) final-split)
    ::  for each share, calculate coins = (share * total-coins) / total-shares
    ::  and track remainders for redistribution
    =/  new-split=(list [=lock share=@ total=coins this=coins])
      %+  turn  split
      |=  [=lock share=@ current-coins=coins]
      =/  coins-for-share=coins
        (div (mul share remaining-coins) total-shares)
      [lock share (add current-coins coins-for-share) coins-for-share]
    ::  calculate what's left to distribute
    =/  distributed=coins
      %+  roll  new-split
      |=  [[=lock s=@ c=coins this=coins] sum=coins]
      (add this sum)
    ?:  =(0 distributed)
      ::  if no coins were distributed this round, just give the remainder to
      ::  the first share
      =/  final-split=(list [lock coins])
        (turn new-split |=([l=lock s=@ t=coins h=coins] [l t]))
      =/  first=[l=lock c=coins]  (snag 0 final-split)
      =.  c.first  (add c.first remaining-coins)
      =.  final-split  [first (slag 1 final-split)]
      (~(gas z-by *form) final-split)
    =/  still-remaining=@  (sub remaining-coins distributed)
    %=  $
      split            (turn new-split |=([l=lock s=@ t=coins h=coins] [l s t]))
      remaining-coins  still-remaining
      recursion-depth  +(recursion-depth)
    ==
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    ?~  form  leaf+form
    :+  [(hashable:lock p.n.form) leaf+q.n.form]
      $(form l.form)
    $(form r.form)
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $seed: carrier of a quantity of assets from an $input to an $output
++  seed
  =<  form
  |%
  +$  form
    $:  ::    if non-null, enforces that output note must have precisely
        ::    this source
        output-source=(unit source)
        ::    the .lock of the output note
        recipient=lock
        ::    if non-null, enforces that output note must have precisely
        ::    this timelock (though [~ ~ ~] means ~). null means there
        ::    is no intent.
        =timelock-intent
        ::    quantity of assets gifted to output note
        gift=coins
        ::   check that parent hash of every seed is the hash of the
        ::   parent note
        parent-hash=^hash
    ==
  ++  new
    =<  default
    |%
    ++  default
      |=  $:  output-source=(unit source)
              recipient=lock
              =timelock-intent
              gift=coins
              parent-hash=^hash
          ==
      %*  .  *form
        output-source    output-source
        recipient        recipient
        timelock-intent  timelock-intent
        gift             gift
        parent-hash      parent-hash
      ==
    ::  +simple: helper constructor with no timelock intent or output source
    ++  simple
      =<  default
      |%
      ++  default
        |=  [recipient=lock gift=coins parent-hash=^hash]
        ^-  form
        (new *(unit source) recipient *timelock-intent gift parent-hash)
      ::
      ::  +from-note: seed sending all coins from a $ to recipient
      ++  from-note
        |=  [recipient=lock note=nnote]
        ^-  form
        (simple recipient assets.note (hash:nnote note))
      --
    ::  delete this? there is no difference between multi and simple cases
    ++  multisig
      =<  default
      |%
      ++  default
        |=  [recipients=lock gift=coins parent-hash=^hash]
        ^-  form
        (new *(unit source) recipients *timelock-intent gift parent-hash)
      ::
      ++  from-note
        |=  [recipients=lock note=nnote]
        ^-  form
        (multisig recipients assets.note (hash:nnote note))
      --
    --
  ::
  ::  +hashable: we don't include output-source since it could create a hash loop
  ++  hashable
    |=  sed=form
    ^-  hashable:tip5
    :^    (hashable:lock recipient.sed)
      (hashable:timelock-intent timelock-intent.sed)
      leaf+gift.sed
    hash+parent-hash.sed
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
++  seeds
  =<  form
  ~%  %seeds  ..seeds  ~
  |%
  +$  form  (z-set seed)
  ::
  ++  new
    =<  default
    |%
    ++  default
      |=  seds=(list seed)
      ^-  form
      (~(gas z-in *form) seds)
    ::  +new-simple-from-note-with-refund: sends gift to recipient and remainder to owner of note
    ++  simple-from-note-with-refund
      =<  default
      |%
      ::  +default:
      ::
      ::    while the sample has a .fee, this is just to account for the size of
      ::    the refund. the .fee is stored one level up, in $spend. since this is
      ::    a constructor for building a tx with only one note, we necessarily
      ::    need to take the fee into account here.
      ++  default
        |=  [recipient=lock gift=coins fee=coins note=nnote]
        ^-  form
        (with-choice recipient gift fee note lock.note)
      ::
      ::  +with-choice: choose the refund address
      ++  with-choice
        |=  $:  recipient=lock
                gift=coins
                fee=coins
                note=nnote
                refund-address=lock
            ==
        ^-  form
        ?>  (lte (add gift fee) assets.note)
        =/  refund=coins  (sub assets.note (add gift fee))
        =/  gift-seed=seed
          (simple:new:seed recipient gift (hash:nnote note))
        =/  refund-seed=seed
          (multisig:new:seed refund-address refund (hash:nnote note))
        =/  seed-list=(list seed)
          ::  if there is no refund, don't use the refund seed
          ?:  =(0 refund)  ~[gift-seed]
          ~[gift-seed refund-seed]
        (new seed-list)
      --
    --
  ::
  ++  hashable
    |=  =form
    ^-  hashable:tip5
    ?~  form  leaf+form
    :+  (hashable:seed n.form)
      $(form l.form)
    $(form r.form)
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $spend: a signed collection of seeds used in an $input
::
::    .signature: expected to be on the hash of the spend's seeds
::
::    .seeds: the individual transfers to individual output notes
::    that the spender is authorizing
++  spend
  =<  form
  ~%  %spend  ..spend  ~
  |%
  +$  form
    $:  signature=(unit signature)
      ::  everything below here is what is hashed for the signature
        =seeds
        fee=coins
    ==
  ::
  ++  new
    =<  default
    |%
    ++  default
      |=  [=seeds fee=coins]
      %*  .  *form
        seeds  seeds
        fee    fee
      ==
    ::
    ::  +simple-from-note: generates a $spend sending all assets to recipient from note
    ++  simple-from-note
      =<  default
      |%
      ++  default
        |=  [recipient=lock note=nnote]
        ^-  form
        =;  sed=seed  (new (~(put z-in *seeds) sed) 0)
        (from-note:simple:new:seed recipient note)
      ::
      ::  +with-refund: returns unspent assets to note owner
      ++  with-refund
        =<  default
        |%
        ++  default
          |=  [recipient=lock gift=coins fee=coins note=nnote]
          ^-  form
          =;  seds=seeds  (new seds fee)
          (simple-from-note-with-refund:new:seeds recipient gift fee note)
        ::
        ::  +with-choice: choose which address receives the refund
        ++  with-choice
          |=  $:  recipient=lock
                  gift=coins
                  fee=coins
                  note=nnote
                  refund-address=lock
              ==
          ^-  form
          =;  seds=seeds  (new seds fee)
          %-  with-choice:simple-from-note-with-refund:new:seeds
          [recipient gift fee note refund-address]
        --
      --
    --
  ::
  ::  +sign: add a single signature to the seeds
  ::
  ::    .sen: the $spend we are signing
  ::    .sk: the secret key being used to sign
  ++  sign
    ~/  %sign
    |=  [sen=form sk=schnorr-seckey]
    ^+  sen
    ::  we must derive the pubkey from the seckey
    =/  pk=schnorr-pubkey
      %-  ch-scal:affine:curve:cheetah
      :*  (t8-to-atom:belt-schnorr:cheetah sk)
          a-gen:curve:cheetah
      ==
    =/  sig=schnorr-signature
      %+  sign:affine:belt-schnorr:cheetah
        sk
      (leaf-sequence:shape (sig-hash sen))
    ?:  =(~ signature.sen)
      %_  sen
        signature  (some (~(put z-by *signature) pk sig))
      ==
    %_  sen
      signature  (some (~(put z-by (need signature.sen)) pk sig))
    ==
  ::
  ::  +verify: verify the .signature and each seed has correct parent-hash
  ++  verify
    ~/  %verify
    |=  [sen=form parent-note=nnote]
    ^-  ?
    ?~  signature.sen  %.n
    =/  parent-hash=hash  (hash:nnote parent-note)
    ::  check that parent hash of each seed matches the note's hash
    ?.  (~(all z-in seeds.sen) |=(sed=seed =(parent-hash.sed parent-hash)))
      %.n
    ::
    =/  have-pks=(z-set schnorr-pubkey)  ~(key z-by u.signature.sen)
    ::  are there at least as many sigs as m.lock?
    ?:  (lth ~(wyt z-in have-pks) m.lock.parent-note)
      %.n
    ::  check that the keys in .signature are a subset of the keys in the lock
    ?.  =((~(int z-in pubkeys.lock.parent-note) have-pks) have-pks)
    ::   =/  base58-have-pks=(list @t)
    ::     %+  turn  ~(tap z-by have-pks)
    ::     to-b58:schnorr-pubkey
    ::   =/  base58-pubkeys=(list @t)
    ::     %+  turn  ~(tap z-by pubkeys.lock.parent-note)
    ::     to-b58:schnorr-pubkey
      ::  intersection of pubkeys in .lock and pubkeys in .signature does not equal
      ::  the pubkeys in .signature
      :: ~&  >>  "invalid signatures"
      :: ~&  >>  "have-pks: {<base58-have-pks>}"
      :: ~&  >>  "pubkeys.lock.parent-note: {<base58-pubkeys>}"
      %.n
    ::  we have enough signatures, they're all from the set of pubkeys required
    ::  by the lock, so now we can actually verify them.
    ::
    ::  we validate all signatures, even if there are more than m, since
    ::  saying a transaction is valid with invalid signatures just seems wrong.
    %-  ~(all z-in have-pks)
    |=  pk=schnorr-pubkey
    %:  verify:affine:belt-schnorr:cheetah
        pk
        (leaf-sequence:shape (sig-hash sen))
        (~(got z-by u.signature.sen) pk)
    ==
  ::
  ++  hashable
    |=  sen=form
    ^-  hashable:tip5
    :+  ?~(signature.sen %leaf^~ [%leaf^~ (hashable:signature u.signature.sen)])
      (hashable:seeds seeds.sen)
    leaf+fee.sen
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  ::
  ::  +sig-hash: the hash used for signing and verifying
  ++  sig-hash
    |=  sen=form
    ^-  hash
    %-  hash-hashable:tip5
    [(hashable:seeds seeds.sen) leaf+fee.sen]
  --
::
::  $input: note transfering assets to outputs within a tx
::
::    .note: the note that is transferring assets to outputs within the tx.
::    the note must exist in the balance in order for it to spend, and it must
::    be removed from the balance atomically as it spends.
::
::    .spend: authorized commitment to the recipient notes that the input is
::    transferring assets to and amount of assets given to each output.
++  input
  =<  form
  ~%  %input  ..input  ~
  |%
  +$  form  [note=nnote =spend]
  ::
  ++  new
    =<  default
    |%
    ++  default
      |=  [not=nnote =seeds fee=coins sk=schnorr-seckey]
      ^-  form
      =/  sen
        %+  sign:spend
          (new:spend seeds fee)
        sk
      [not sen]
    ::
    ::  +simple-from-note: send all assets in note to recipient
    ++  simple-from-note
      =<  default
      |%
      ++  default
        |=  [recipient=lock not=nnote sk=schnorr-seckey]
        ^-  form
        =/  sen=spend  (simple-from-note:new:spend recipient not)
        =.  sen
          %+  sign:spend
            sen
          sk
        [not sen]
      ::
      ++  with-refund
        =<  default
        |%
        ++  default
          |=  [recipient=lock gift=coins fee=coins not=nnote sk=schnorr-seckey]
          ^-  form
          =/  sen=spend
            (with-refund:simple-from-note:new:spend recipient gift fee not)
          =.  sen
            %+  sign:spend
              sen
            sk
          [not sen]
        ::
        ++  with-choice
          |=  $:  recipient=lock
                  gift=coins
                  fee=coins
                  not=nnote
                  sk=schnorr-seckey
                  refund-address=lock
              ==
          ^-  form
          =/  sen=spend
            %-  with-choice:with-refund:simple-from-note:new:spend
            [recipient gift fee not refund-address]
          =.  sen
            %+  sign:spend
              sen
            sk
          [not sen]
        --
      --
    --
  ::
  ::  +validate: verifies whether an $input's .spend is valid by checking the sigs
  ++  validate
    ~/  %validate
    |=  inp=form
    ^-  ?
    =/  check-spend=?  (verify:spend spend.inp note.inp)
    =/  check-gifts-and-fee=?
      =/  gifts-and-fee=coins
        %+  add  fee.spend.inp
        %+  roll  ~(tap z-in seeds.spend.inp)
        |=  [=seed acc=coins]
        :(add acc gift.seed)
      =(gifts-and-fee assets.note.inp)
      ::  total gifts and fee is = assets in the note (coin scarcity)
    :: ~&  >>
    ::  :*  %validate-input
    ::      spend+check-spend
    ::      gifts-and-fees+check-gifts-and-fee
    ::  ==
    ?&(check-spend check-gifts-and-fee)
  ::
  ++  hashable
    |=  inp=form
    ^-  hashable:tip5
    :-  (hashable:nnote note.inp)
    (hashable:spend spend.inp)
  ::
  ++  hash  |=(=form (hash-hashable:tip5 (hashable form)))
  --
::
::  $output: recipient of assets transferred by some inputs in a tx
::
::    .note: the recipient of assets transferred by some inputs in a tx,
::    and is added to the balance atomically with it receiving assets.
::
::    .seeds: the "carrier" for the individual asset gifts it receives from
::    each input that chose to spend into it.
++  output
  =<  form
  ~%  %output  ..output  ~
  |%
  +$  form  [note=nnote =seeds]
  ::
  ::  +compute-source: computes the source for the note from .seeds
  ::
  ::    not to be used for coinbases - use new:coinbase
  ++  compute-source
    |=  out=form
    ^-  source
    :_  %.n  :: is-coinbase
    (hash:seeds seeds.out)
  ::
  ++  validate
    ~/  %validate
    |=  out=form
    ^-  ?
    =/  source-check=?
      %+  levy  ~(tap z-in seeds.out)
      |=  =seed
      ?~  output-source.seed  %.y
      =(u.output-source.seed source.note.out)
    =/  assets-check=?
      =/  calc-assets=coins
        %+  roll  ~(tap z-in seeds.out)
        |=  [=seed acc=coins]
        (add gift.seed acc)
      =(calc-assets assets.note.out)
    &(source-check assets-check)
  --
::
::  $tx-acc: accumulator for updating balance while processing txs
::
::    ephemeral struct for incrementally updating balance per tx in a page,
::    and for accumulating fees and size per tx processed, to be checked
::    against the coinbase assets and max-page-size
++  tx-acc
  =<  form
  ~%  %tx-acc  ..tx-acc  ~
  |%
  +$  form
    $:  balance=(z-map nname nnote)
        fees=coins
        =size
        txs=(z-set tx)
    ==
  ::
  ::  +new: pass in the balance of the parent block to initialize the accumulator for current block
  ++  new
    ~/  %new
    |=  bal=(unit (z-map nname nnote))
    ::  the unit stuff is to account for the genesis block
    %*  .  *form
      balance  ?~  bal  *(z-map nname nnote)
               u.bal
    ==
  ::
  ++  process
    ~/  %process
    |=  [tx-acc=form =tx new-page-number=page-number]
    ^-  (unit form)
    %-  mole
    |.
    ~|  "tx invalid"
    ?>  (validate:^tx tx new-page-number)
    ::
    ::  check that adding size of tx will not cause block size to be exceeded
    =/  new-size=size  (add size.tx-acc total-size.tx)
    ?.  (lte new-size max-block-size)
      ~|  "adding new transaction {<id.tx>} would exceed max block size"
      !!
    ::
    ::  process outputs
    =.  balance.tx-acc
      %+  roll  ~(val z-by outputs.tx)
      |=  [op=output bal=_balance.tx-acc]
      ?:  (~(has z-by bal) name.note.op)
        ~|  "tx output already exists in balance"
        !!
      (~(put z-by bal) name.note.op note.op)
    ::
    ::  process inputs
    =/  [tic=timelock-range tac=form]
      %+  roll  ~(val z-by inputs.tx)
      |=  [ip=input tic=timelock-range tac=_tx-acc]
      ?.  =((some note.ip) (~(get z-by balance.tx-acc) name.note.ip))
        ~|  "tx input does not exist in balance"  !!
      =.  balance.tac  (~(del z-by balance.tac) name.note.ip)
      =.  fees.tac  (add fees.tac fee.spend.ip)
      =.  tic
        %+  merge:timelock-range  tic
        %+  fix-absolute:timelock
          timelock.note.ip
        origin-page.note.ip
      [tic tac]
    ::
    ?.  (check:timelock-range tic new-page-number)
      ~|  "failed timelock check"  !!
    ::
    %_  tac
      size  new-size
      txs   (~(put z-in txs.tac) tx)
    ==
  --
--
