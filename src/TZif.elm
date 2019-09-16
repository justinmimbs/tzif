module TZif exposing (decode)

{-|

@docs decode

-}

import Bytes exposing (Bytes)
import Bytes.Decode as Decode exposing (Decoder)
import Time


{-| Decode a TZif file into a `Time.Zone` value.

    import Bytes.Decode
    import TZif
    import Time

    zone : Maybe Time.Zone
    zone =
        Bytes.Decode.decode TZif.decode tzif

-}
decode : Decoder Time.Zone
decode =
    decodeHeader
        |> Decode.andThen
            (\header1 ->
                if header1.version == V1 then
                    decodeBlock header1

                else
                    Decode.bytes (blockLengthV1 header1)
                        |> Decode.andThen (always decodeHeader)
                        |> Decode.andThen decodeBlock
            )
        |> Decode.andThen blockToZone


decodeMagic : Decoder ()
decodeMagic =
    Decode.string 4
        |> Decode.andThen
            (\string ->
                if string == "TZif" then
                    Decode.succeed ()

                else
                    Decode.fail
            )


type Version
    = V1
    | V2
    | V3


decodeVersion : Decoder Version
decodeVersion =
    Decode.string 1
        |> Decode.andThen
            (\v ->
                case v of
                    "\u{0000}" ->
                        Decode.succeed V1

                    "2" ->
                        Decode.succeed V2

                    "3" ->
                        Decode.succeed V3

                    _ ->
                        Decode.fail
            )


type alias Header =
    { version : Version
    , isutCount : Int
    , isstdCount : Int
    , leapCount : Int
    , timeCount : Int
    , typeCount : Int
    , charCount : Int
    }


decodeHeader : Decoder Header
decodeHeader =
    Decode.succeed Header
        |> skip decodeMagic
        |> take decodeVersion
        |> skip (Decode.bytes 15)
        |> take decodeUnsignedInt32
        |> take decodeUnsignedInt32
        |> take decodeUnsignedInt32
        |> take decodeUnsignedInt32
        |> take decodeUnsignedInt32
        |> take decodeUnsignedInt32


blockLengthV1 : Header -> Int
blockLengthV1 { isutCount, isstdCount, leapCount, timeCount, typeCount, charCount } =
    let
        timeSize =
            4
    in
    (timeCount * timeSize)
        + timeCount
        + (typeCount * 6)
        + charCount
        + (leapCount * (timeSize + 4))
        + isstdCount
        + isutCount


{-| The data block has seven sections, but we're only interested in three.
-}
type alias Block =
    { transitionTimes : List Int
    , transitionTypes : List Int
    , typeOffsets : List Int
    }


decodeBlock : Header -> Decoder Block
decodeBlock header =
    let
        decodeTime =
            if header.version == V1 then
                decodeSignedInt32

            else
                decodeSignedInt64
    in
    Decode.map3
        Block
        (decodeList header.timeCount decodeTime)
        (decodeList header.timeCount Decode.unsignedInt8)
        (decodeList header.typeCount decodeTypeOffset |> Decode.map List.reverse)


{-| From each type record, we're only interested in the UTC offset.
-}
decodeTypeOffset : Decoder Int
decodeTypeOffset =
    Decode.map2 always decodeSignedInt32 (Decode.bytes 2)



--


blockToZone : Block -> Decoder Time.Zone
blockToZone { transitionTimes, transitionTypes, typeOffsets } =
    case typeOffsets of
        [] ->
            Decode.fail

        defaultOffset :: _ ->
            let
                changes =
                    List.map2
                        (\time typeIndex ->
                            let
                                offset =
                                    typeOffsets |> List.drop typeIndex |> List.head |> Maybe.withDefault defaultOffset
                            in
                            { start = time // 60, offset = offset // 60 }
                        )
                        transitionTimes
                        transitionTypes
            in
            Decode.succeed (Time.customZone (defaultOffset // 60) changes)



-- decode helpers


take : Decoder a -> Decoder (a -> b) -> Decoder b
take dx df =
    Decode.map2 (\f x -> f x) df dx


skip : Decoder a -> Decoder b -> Decoder b
skip da db =
    Decode.map2 (\b _ -> b) db da


decodeUnsignedInt32 : Decoder Int
decodeUnsignedInt32 =
    Decode.unsignedInt32 Bytes.BE


decodeSignedInt32 : Decoder Int
decodeSignedInt32 =
    Decode.signedInt32 Bytes.BE


decodeSignedInt64 : Decoder Int
decodeSignedInt64 =
    Decode.map2 (\a b -> a * (2 ^ 32) + b) decodeSignedInt32 decodeUnsignedInt32


{-| Returns a reversed list as a minor optimization; the list of transitions
are stored in ascending order but must be in descending order for Time.Zone,
so this avoids reversing the transition lists unnecessarily.
-}
decodeList : Int -> Decoder a -> Decoder (List a)
decodeList count decodeItem =
    Decode.loop ( count, [] ) (decodeListStep decodeItem)


decodeListStep : Decoder a -> ( Int, List a ) -> Decoder (Decode.Step ( Int, List a ) (List a))
decodeListStep decodeItem ( n, list ) =
    if n <= 0 then
        Decode.succeed (Decode.Done list)

    else
        decodeItem |> Decode.map (\item -> Decode.Loop ( n - 1, item :: list ))
