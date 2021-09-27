module GetZone exposing (main)

import Browser
import Bytes.Decode
import Html exposing (Html)
import Html.Attributes
import Http
import TZif
import Task
import Time exposing (Month(..), Posix)


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
    | Success String Time.Zone


type Msg
    = ReceivedZoneName Time.ZoneName
    | ReceivedZone String (Result Http.Error Time.Zone)


init : ( Model, Cmd Msg )
init =
    ( Loading
    , Time.getZoneName |> Task.perform ReceivedZoneName
    )


getZoneByName : String -> Cmd Msg
getZoneByName zoneName =
    Http.get
        { url = "/dist/2021b/" ++ zoneName
        , expect = Http.expectBytes (ReceivedZone zoneName) TZif.decode
        }



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedZoneName nameOrOffset ->
            case nameOrOffset of
                Time.Name zoneName ->
                    ( Loading
                    , getZoneByName zoneName
                    )

                Time.Offset _ ->
                    ( Failure "Could not get local zone name"
                    , Cmd.none
                    )

        ReceivedZone zoneName result ->
            ( case result of
                Ok zone ->
                    Success zoneName zone

                Err error ->
                    case error of
                        Http.BadBody message ->
                            Failure message

                        _ ->
                            Failure "HTTP request failed"
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

            Success zoneName zone ->
                [ Html.pre
                    []
                    [ [ "Examples of Posix times displayed in UTC and your local time:"
                      , ""
                      , "UTC              | " ++ zoneName
                      , "---------------- | ----------------"
                      ]
                        ++ ([ 1689782246881
                            , 1561825998564
                            , 1512980764516
                            , 1501214531979
                            , 1467083800795
                            , 1131357044194
                            , 867564229068
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
        [ String.join "-"
            [ Time.toYear zone posix |> String.fromInt
            , Time.toMonth zone posix |> monthToNumber |> String.fromInt |> String.padLeft 2 '0'
            , Time.toDay zone posix |> String.fromInt |> String.padLeft 2 '0'
            ]
        , String.join ":"
            [ Time.toHour zone posix |> String.fromInt |> String.padLeft 2 '0'
            , Time.toMinute zone posix |> String.fromInt |> String.padLeft 2 '0'
            ]
        ]


monthToNumber : Month -> Int
monthToNumber m =
    case m of
        Jan ->
            1

        Feb ->
            2

        Mar ->
            3

        Apr ->
            4

        May ->
            5

        Jun ->
            6

        Jul ->
            7

        Aug ->
            8

        Sep ->
            9

        Oct ->
            10

        Nov ->
            11

        Dec ->
            12
