module Examples exposing (main)

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
    | Failure String
    | Success ( String, Time.Zone )


type Msg
    = ReceivedZone (Result String ( String, Time.Zone ))


init : ( Model, Cmd Msg )
init =
    ( Loading
    , getZone "/dist/2019c"
        |> Task.attempt ReceivedZone
    )


getZone : String -> Task String ( String, Time.Zone )
getZone basePath =
    Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        getZoneByName basePath zoneName
                            |> Task.map (Tuple.pair zoneName)

                    Time.Offset _ ->
                        Task.fail "No zone name"
            )


getZoneByName : String -> String -> Task String Time.Zone
getZoneByName basePath zoneName =
    Http.task
        { method = "GET"
        , headers = []
        , url = basePath ++ "/" ++ zoneName
        , body = Http.emptyBody
        , resolver =
            Http.bytesResolver
                (\response ->
                    case response of
                        Http.GoodStatus_ _ tzif ->
                            tzif |> Bytes.Decode.decode TZif.decode |> Result.fromMaybe "Failed to decode TZif"

                        _ ->
                            Err "HTTP error"
                )
        , timeout = Nothing
        }



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceivedZone result) _ =
    ( case result of
        Ok data ->
            Success data

        Err message ->
            Failure message
    , Cmd.none
    )



-- view


view : Model -> Browser.Document Msg
view model =
    Browser.Document
        "Get Zone"
        (case model of
            Loading ->
                [ Html.pre [] [ Html.text "Loading..." ] ]

            Failure message ->
                [ Html.pre [ Html.Attributes.style "color" "red" ] [ Html.text message ] ]

            Success ( zoneName, zone ) ->
                [ Html.pre
                    []
                    [ [ "Examples of Posix times displayed in UTC and your local time:"
                      , ""
                      , "UTC                      | " ++ zoneName
                      , "------------------------ | ------------------------"
                      ]
                        ++ ([ 867564229068
                            , 1131357044194
                            , 1467083800795
                            , 1501214531979
                            , 1512980764516
                            , 1561825998564
                            , 1689782246881
                            ]
                                |> List.map Time.millisToPosix
                                |> List.map
                                    (\posix ->
                                        (posix |> formatPosix Time.utc) ++ " | " ++ (posix |> formatPosix zone)
                                    )
                           )
                        |> String.join "\n"
                        |> Html.text
                    ]
                ]
        )


formatPosix : Time.Zone -> Posix -> String
formatPosix zone posix =
    String.join " "
        [ Time.toWeekday zone posix |> weekdayToName
        , Time.toMonth zone posix |> monthToName
        , Time.toDay zone posix |> String.fromInt |> String.padLeft 2 '0'
        , Time.toYear zone posix |> String.fromInt
        , String.join ":"
            [ Time.toHour zone posix |> String.fromInt |> String.padLeft 2 '0'
            , Time.toMinute zone posix |> String.fromInt |> String.padLeft 2 '0'
            , Time.toSecond zone posix |> String.fromInt |> String.padLeft 2 '0'
            ]
        ]


monthToName : Month -> String
monthToName m =
    case m of
        Jan ->
            "Jan"

        Feb ->
            "Feb"

        Mar ->
            "Mar"

        Apr ->
            "Apr"

        May ->
            "May"

        Jun ->
            "Jun"

        Jul ->
            "Jul"

        Aug ->
            "Aug"

        Sep ->
            "Sep"

        Oct ->
            "Oct"

        Nov ->
            "Nov"

        Dec ->
            "Dec"


weekdayToName : Weekday -> String
weekdayToName wd =
    case wd of
        Mon ->
            "Mon"

        Tue ->
            "Tue"

        Wed ->
            "Wed"

        Thu ->
            "Thu"

        Fri ->
            "Fri"

        Sat ->
            "Sat"

        Sun ->
            "Sun"
