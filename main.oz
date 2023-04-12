functor
import 
	QTk at 'x-oz://system/wp/QTk.ozf'
	System
	Application
	Open
	OS
	Property
	Browser
define
	% Pour ouvrir les fichiers

	class TextFile
		from Open.file Open.text
	end

	proc {Browse Buf}
		{Browser.browse Buf}
	end

	% === global var ===
	InputText 
	OutputText
	Files
	% === === == === ===

	% /!\ Fonction testee /!\
	% @pre: les threads sont "ready"
	% @post: Fonction appellee lorsqu on appuie sur le bouton de prediction
	%		  Affiche la prediction la plus probable du prochain mot selon les deux derniers mots entres
	% @return: Retourne une liste contenant la liste du/des mot(s) le(s) plus probable(s) accompagnee de
	%			 la probabilite/frequence la plus elevée.
	%			 La valeur de retour doit prendre la forme:
	%						<return_val> := <most_probable_words> '|' <probability/frequence> '|' nil
	%						<most_probable_words> := <atom> '|' <most_probable_words>
	%														 | nil
	%						<probability/frequence> := <int> | <float>

	fun {Press}
		local Out in
			{InputText get(1: Out)}
			{OutputText set(1: {String.toAtom Out})}
		end
		% TODO
		0
	end

	proc {OnPress ?R}
		R = {Press}
	end

	% Lance les N threads de lecture et de parsing qui liront et traiteront tous les fichiers
	% Les threads de parsing envoient leur resultat au port Port

	proc {LaunchThreads Port N}
		% TODO
		skip
	end

	% Ajouter vos fonctions et procédures auxiliaires ici


	% Fetch Tweets Folder from CLI Arguments
	% See the Makefile for an example of how it is called

	fun {GetSentenceFolder}
		Args = {Application.getArgs record(
			'folder'(
				single
				type: string
				optional: false
			)
		)}
	in
		Args.'folder'
	end

	% Decomnentez moi si besoin
	proc {ListAllFiles L}
		case L of nil then skip
		[] H|T then {Browse {String.toAtom H}} {ListAllFiles T}
		end
	end

	fun {GetFileContent File} % File = 'tweets/...'
		F = {New TextFile init(name:File flags:[read])}
		L 
	in 
		{Browse File}
		{F read(list:L size:all)}
		L
	end

	fun {GetFiles L} % L = {OS.getDir TweetsFolder}
		case L 
			of nil then nil
			[] H|T then {String.toAtom {Append "tweets/" H}}|{GetFiles T} % gives: 'tweets/fileX.txt'
		end
	end

	% Usefull function for later: {File GetS($)} -> gives the next line etc etc

	proc {PrintFilesContent L}
		case L 
			of nil then skip
			[] H|T then {Browse {GetFileContent H}} {PrintFilesContent T}
		end
	end
		

	% Procedure principale qui cree la fenetre et appelle les differentes procedures et fonctions
	proc {Main}
		TweetsFolder = {GetSentenceFolder}
		Files = {GetFiles {OS.getDir TweetsFolder}} % Files = 'tweets/part1.txt' '|' ... '|' nil
	in
		% Fonction d'exemple qui liste tous les fichiers
		% contenus dans le dossier passe en Argument.
		% Inspirez vous en pour lire le contenu des fichiers
		% se trouvant dans le dossier
		% N'appelez PAS cette fonction lors de la phase de
		% soumission !!!

		% {PrintFilesContent Files} % Just prints all the content of files 

		local NbThreads Description Window SeparatedWordsStream SeparatedWordsPort in
			{Property.put print foo(
				width: 1000
				depth: 1000
			)}

			% TODO

			% Creation de l'interface graphique
			% R will store {Press} result

			local R in
				Description=td(
					
					title: "GPT-OZ 4"
					background: c(52 53 65)

					td(
						height: 300
						width: 400
						background: c(52 53 65)
						padx: 50
						pady:30 
						
						label(
							text: "GPT-OZ 4"
							foreground: white
							glue: nswe
							pady: 10
							background: c(52 53 65)
						)

						lr( % three columns 
							width: 300
							height: 100
							background: c(52 53 65)

							td(
								glue:wns
								background: c(52 53 65)
								padx:10

								label(
									text: "Examples"
									foreground: white
									background: c(52 53 65)
									pady: 5
									glue: nwe
								)

								label(
									text: "Tesla is ...\nshareholders'\nvictory."
									foreground: white
									background: c(64 65 79)
									pady:5
									glue: nwe 
								)

								label(
									text: "I am ...\nclose\npoverty."
									foreground: white
									background: c(64 65 79)
									pady:5
									glue: nwe
								)

								label(
									text: "I should...\nresell Twitter."
									foreground: white
									background: c(64 65 79)
									pady:5
									glue: nwe
								)
							)

							td(
								glue:wns
								background: c(52 53 65)
								padx:10

								label(
									text: "Possibilities"
									foreground: white
									background: c(52 53 65)
									pady: 5
									glue: nwe
								)

								label(
									text: "Get automatic\nTweets"
									foreground: white
									background: c(64 65 79)
									pady: 5
									glue: nwe 
								)

								label(
									text: "2-grammes\nprediction\nbased"
									foreground: white
									background: c(64 65 79)
									pady: 5
									glue: nwe
								)

								label(
									text: "Easy and\ncomplete\ntweets"
									foreground: white
									background: c(64 65 79)
									pady: 5
									glue: nwe
								)
							)

							td(
								glue:wns
								background: c(52 53 65)
								padx:10

								label(
									text: "Limitations"
									foreground: white
									background: c(52 53 65)
									pady: 5
									glue: nwe
								)

								label(
									text: "Elon Musk\ntweetosphere"
									foreground: white
									background: c(64 65 79)
									pady: 8
									glue: nwe 
								)

								label(
									text: "Maximum \nresponse\nof 100 words"
									foreground: white
									background: c(64 65 79)
									pady: 8
									glue: nwe
								)

								label(
									text: "Oz slowness\n& bugs"
									foreground: white
									background: c(64 65 79)
									pady: 8
									glue: nwe
								)
							)
						)

						text(
							handle: OutputText
							width: 100
							height: 10
							background: c(52 53 65)
							highlightthickness:0
							foreground: white
							glue: nswe
							wrap: word
							borderwidth: 0
						)

						text(
							glue: nswe
							handle: InputText
							width: 100
							height: 5
							background: c(64 65 79)
							borderwidth: 2
							foreground: white
							wrap: word
						)
						
						button(
							text: "PREDICT"
							relief: groove
							foreground: c(52 53 65)
							background: white 
							width: 10
							glue: s
							action: proc {$}
								{OnPress R}
							end
						)

						label(
							text: "@GPT-OZ 4 is under MIT license & still in development. \nNo warranty of work is given and it should be used at your own risk. "
							foreground: white
							glue: swe
							pady: 20
							background: c(52 53 65)
						)						
					)

				% quit program when window is closed

				action: proc {$}
					{Application.exit 0}
				end
				)

				% window creation

				Window = {QTk.build Description}
				{Window show}

				{InputText tk(insert 'end' "Loading... Please wait.")}

				{InputText bind(
					event: "<Control-s>"
					action: proc {$}
						{OnPress R}
					end
				)}

				% TODO we can use R now, it contains the result of the search in files
			end

			% On lance les threads de lecture et de parsing

			SeparatedWordsPort = {NewPort SeparatedWordsStream}
			NbThreads = 4
			{LaunchThreads SeparatedWordsPort NbThreads}

			{InputText set(
				1: ""
			)}
		end
	end

	% call main procedure

	{Main}
end
