module Zones exposing (main)

{-| This page attempts to fetch and decode a set of TZif files.
-}

import Browser
import Bytes.Decode
import Html exposing (Html)
import Html.Attributes
import Http
import TZif
import Task exposing (Task)
import Time exposing (Month(..), Posix, Weekday(..))


main : Program () Model Msg
main =
    Browser.document
        { init = always init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type Model
    = Loading
    | NoList
    | Active ZoneList


type alias ZoneList =
    { todo : List String
    , done : List ( String, Result Http.Error Time.Zone )
    }


type Msg
    = ReceivedZoneList (Result Http.Error String)
    | ReceivedZone String (Result Http.Error Time.Zone)


init : ( Model, Cmd Msg )
init =
    ( Loading
    , Http.get
        { url = "zoneinfo/zones.text"
        , expect = Http.expectString ReceivedZoneList
        }
    )


getZoneByName : String -> Cmd Msg
getZoneByName zoneName =
    Http.get
        { url = "zoneinfo/" ++ zoneName
        , expect = Http.expectBytes (ReceivedZone zoneName) TZif.decode
        }



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedZoneList result ->
            case result of
                Ok string ->
                    { todo = string |> String.lines |> List.filter ((/=) "")
                    , done = []
                    }
                        |> loadNextZone

                Err error ->
                    ( NoList
                    , Cmd.none
                    )

        ReceivedZone zoneName result ->
            case model of
                Active { todo, done } ->
                    { todo = List.drop 1 todo
                    , done = ( zoneName, result ) :: done
                    }
                        |> loadNextZone

                _ ->
                    ( model, Cmd.none )


loadNextZone : ZoneList -> ( Model, Cmd Msg )
loadNextZone zones =
    ( Active zones
    , case zones.todo of
        [] ->
            Cmd.none

        zoneName :: _ ->
            getZoneByName zoneName
    )



-- view


view : Model -> Browser.Document Msg
view model =
    Browser.Document
        "Zones"
        (case model of
            Loading ->
                [ Html.pre [] [ Html.text "Loading..." ] ]

            NoList ->
                [ Html.pre [ Html.Attributes.style "color" "red" ] [ Html.text "Failed to load zone names.\nRun the build script and try this page again." ] ]

            Active zones ->
                let
                    todoCount =
                        zones.todo |> List.length

                    doneCount =
                        zones.done |> List.length

                    errorCount =
                        (zones.done |> List.filter (Tuple.second >> isErr)) |> List.length

                    summary =
                        [ Html.text <| "Loaded:  " ++ ((doneCount - errorCount) |> String.fromInt |> String.padLeft 3 ' ') ++ "\n"
                        , Html.text <| "Failed:  " ++ (errorCount |> String.fromInt |> String.padLeft 3 ' ') ++ "\n"
                        , Html.text <| "Waiting: " ++ (todoCount |> String.fromInt |> String.padLeft 3 ' ') ++ "\n"
                        , Html.text "\n"
                        ]
                in
                [ Html.pre [] <|
                    summary
                        ++ (zones.done |> List.reverse |> List.map viewDone)
                        ++ (zones.todo |> List.map viewTodo)
                ]
        )


viewTodo : String -> Html a
viewTodo zoneName =
    Html.span [ Html.Attributes.style "color" "gray" ] [ Html.text ("[ ] " ++ zoneName ++ "\n") ]


viewDone : ( String, Result Http.Error Time.Zone ) -> Html a
viewDone ( zoneName, result ) =
    let
        ( color, message ) =
            case result of
                Ok _ ->
                    ( "black", "" )

                Err error ->
                    ( "red"
                    , case error of
                        Http.BadBody str ->
                            " (" ++ str ++ ")"

                        Http.BadStatus statusCode ->
                            " (" ++ String.fromInt statusCode ++ ")"

                        Http.BadUrl str ->
                            " (" ++ str ++ ")"

                        Http.NetworkError ->
                            " (network error)"

                        Http.Timeout ->
                            " (timeout)"
                    )
    in
    Html.span [ Html.Attributes.style "color" color ] [ Html.text ("[x] " ++ zoneName ++ message ++ "\n") ]


isErr : Result x a -> Bool
isErr result =
    case result of
        Err _ ->
            True

        Ok _ ->
            False
