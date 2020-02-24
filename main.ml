let or_die = function
  | Ok x -> x
  | Error (`Msg m) ->
    Fmt.epr "%s@." m;
    exit 1

let one_week = 60. *. 60. *. 24. *. 7.

let last_fetch_file = ".github-activity-timestamp"

let mtime path =
  match Unix.stat path with
  | info -> Some info.Unix.st_mtime
  | exception Unix.Unix_error(Unix.ENOENT, _, _) -> None

let set_mtime path time =
  if not (Sys.file_exists path) then
    close_out @@ open_out_gen [Open_append; Open_creat] 0o600 path;
  Unix.utimes path time time

let get_token () =
  let ( / ) = Filename.concat in
  match Sys.getenv_opt "HOME" with
  | None -> Error (`Msg "$HOME is not set - can't locate GitHub token!")
  | Some home -> Token.load (home / ".github" / "github-activity-token")

(* Run [fn timestamp], where [timestamp] is the last recorded timestamp (if any).
   On success, update the timestamp to the start time. *)
let with_timestamp fn =
  let now = Unix.time () in
  let last_fetch = mtime last_fetch_file in
  fn last_fetch;
  set_mtime last_fetch_file now

let show ~from json =
  Fmt.pr "@[<v>%a@]@." (Contributions.pp ~from) json

let mode = `Normal

let () =
  match mode with
  | `Normal ->
    with_timestamp (fun last_fetch ->
        let from = Option.value last_fetch ~default:(Unix.time () -. one_week) in
        let token = get_token () |> or_die in
        show ~from @@ Contributions.fetch ~from ~token
      )
  | `Save ->
    with_timestamp (fun last_fetch ->
        let from = Option.value last_fetch ~default:(Unix.time () -. one_week) in
        let token = get_token () |> or_die in
        Contributions.fetch ~from ~token
        |> Yojson.Safe.to_file "activity.json"
      )
  | `Load ->
    (* When testing formatting changes, it is quicker to fetch the data once and then load it again for each test: *)
    let from = mtime last_fetch_file |> Option.value ~default:0.0 in
    show ~from @@ Yojson.Safe.from_file "activity.json"