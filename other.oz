declare
fun {FindInSequence SequenceList SentenceList Acc Initial}
    %% Check for Sequence within Sentence:
    %% [Hello I] [Sir Hello I am happy] -> [Hello I] [Hello I am happy] -> [I] [I am happy] -> [am] added
    SenLen = {List.length SentenceList}
    SeqLen = {List.length SequenceList}
in
    local Found Word in
        if SenLen < (SeqLen + 1) then % if not possible because at end of sentence
            Acc
        else
            if SeqLen == 1 then
                if {Strcasecmp SequenceList.1 SentenceList.1} == 1 then
                    Word = SentenceList.2.1 % next word found !
                    Found = 1
                else
                    Word = nil
                    Found = 0
                end
            else
                Word = nil
                Found = 0
            end

            if SeqLen == 0 then
                if Found == 1 then
                    {FindInSequence Initial SentenceList Word|Acc Initial} % restart search with initial sequence
                else
                    {FindInSequence Initial SentenceList Acc Initial}
                end

            elseif {Strcasecmp SequenceList.1 SentenceList.1} == 1 then
                if Found == 1 then % add Word to list and continue checking for equivalence with further words in tail of sentence
                    {FindInSequence SequenceList.2 SentenceList.2 Word|Acc Initial}
                else
                    {FindInSequence SequenceList.2 SentenceList.2 Acc Initial}
                end

            else
                {FindInSequence SequenceList SentenceList.2 Acc Initial} % if no correspondance, continue checking for occurence in tail of sentence, keeping the same sequence list
            end
        end
    end
end

declare
fun {FindinString SequenceString SentenceString}
    %% Strings is a String: "word1 word2",
    %% Sentence a List of String: "word1 word2 word3 word4"
    SentenceList = {String.tokens SentenceString 32} % = Sentence.split(" ")
    SequenceList = {String.tokens SequenceString 32}
in
    {FindInSequence SequenceList SentenceList nil SequenceList}
end



declare 
R = ["salut" "he" "hppa"]

declare 
fun {RemoveNilAux Tokens Acc}
    case Tokens 
        of nil then Acc
        [] H|T then 
            {Browse H}
            if H == nil then
                {RemoveNilAux T Acc}
            else 
                {RemoveNilAux T {Append Acc [H]}}
            end
    end
end

declare
R = ["salut" nil "hppa"]

declare
Z =  {RemoveNilAux R ["salut"]}

{Browse Z}