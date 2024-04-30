FORWARD SEGMENT TABLE (APPEND)
------------------------------
- key: bufID, offset, desc_start_ptr
- value: fragment_ptr

REVERSE SEGMENT TABLE (PREPEND)
------------------------------
- key: bufID, lastOffset, desc_next_ptr
- value: fragment_ptr

FRAGMENT RECORDS
----------------
- state: bufId, start_offset, end_offset, last flag, num_segments, timer

Look up offset of new segment in forward segment table
Look up offset of new segment in reverse segment table

One of four outcomes:
  - find forward entry, no reverse entry
    - append to existing fragment
    - create new forward entry
    - delete previous forward entry

  - find reverse entry, no forward entry
    - prepend to existing fragment
    - create new reverse entry
    - delete previous reverse segment

  - find neither entry
    - first segment or isolated segment
    - create new fragment
    - create new forward entry
    - create new reverse entry (only if offset > 0?)

  - find both entries
    - 'missing' piece
    - concatentate fragments
    - delete previous forward entry
    - delete previous delete entry

Poll fragments:
    - look for monolithic fragments containing entries from 0 to TOTAL_LEN (per buffer)
      - when found:
        - report full buffer
        - remove fragment
        - remove forward segment table entry
        - remove reverse segment table entry
    - look for expired fragments
      - remove fragment
      - remove forward segment table entry
      - remove reverse segment table entry

---

forward cache + reverse cache (in parallel), auto-delete/insert
state read/update




