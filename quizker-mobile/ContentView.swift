//
//  ContentView.swift
//  quizker-mobile
//
//  Created by Piotrek Gałka on 31/10/2023.
//

import SwiftUI
import Alamofire
import PhotosUI



struct ContentView: View {
    @State private var images: [UIImage] = [];
    @State private var photosPickerItems: [PhotosPickerItem] = [];
    @State private var showAlert: Bool = false;
    @State private var score: String = "0%"
    @State private var buttonText: String = "Choose quiz"
    
    @State var state: Int = 0;
    
    @State private var results: [UserResult] = []
    
    @State private var quizzes: [Quiz] = [];
    @State private var selectedQuiz: String = "";
    
    var body: some View {
        ZStack {
            switch state {
            case 0:
                welcomeSection
            case 1:
                selectQuiz
            case 2:
                selectPhotos
            case 3:
                usersResults

            default:
                welcomeSection
            }
        }
        VStack{
                    Spacer()
                    bottomButton
        }
        .padding()
    }
}


struct UploadImagesResponse: Codable {
    let results: [UserApiResponse]
}

struct UserApiResponse: Codable {
    let name: String;
    let score: String;
}

struct Quiz: Codable, Identifiable {
    let name: String;
    let id: String;
}

struct GetQuizzesResponse: Codable {
    let quizzes: [Quiz]
}


struct UserResult: Identifiable {
    var id = UUID()
    
    let name: String;
    let score: String;
}



extension ContentView {
    private var bottomButton: some View{
        Text(buttonText)
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(height: 55)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 5)
            .animation(nil, value: UUID())
            .onTapGesture {
                if state == 2 {
                    upload(images: images)
                }
                nextState()
            }
      
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("Welcome to Quizker")
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()

            Spacer()
            
            
        }
    }
    
    private var selectQuiz: some View {
        VStack(spacing: 30) {
            Spacer()
            Spacer()
            List{
                Picker("Quiz", selection: $selectedQuiz) {
                    ForEach(quizzes) { quiz in
                        Text(quiz.name).tag(quiz.name)
                     }
                }.onAppear { self.fetchQuizes() }
            }.listStyle(PlainListStyle())
        }
    }
    
    private var selectPhotos: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("Select photos of quizzes")
                .font(.title)
                .fontWeight(.semibold)
            PhotosPicker("Select Photos", selection: $photosPickerItems, maxSelectionCount: 5, selectionBehavior: .ordered)
            ScrollView(.horizontal) {
                HStack(spacing: 30) {
                    ForEach(0..<images.count, id : \.self) { i in
                        Image(uiImage: images[i])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                        
                    }
                }
            }
                .padding(30)
                .onChange(of: photosPickerItems) { _, _ in
                    Task {
                        for item in photosPickerItems {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                if let image = UIImage(data: data) {
                                    images.append(image)
                                }
                            }
                        }
                        
                        photosPickerItems.removeAll()
                    }
                }
        }
        
    }

    private var usersResults: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("Results").font(.title).fontWeight(.semibold)
   
            List{
                ForEach(results) {result in
                    HStack {
                        Text(result.name)
                        Spacer()
                        Text(result.score)
                    }.listRowSeparator(.hidden)
                }
            }.listStyle(PlainListStyle())
        }
    }
}




extension ContentView {
    func nextState() {
        switch state {
        case 0:
            buttonText = "Select photos"
        case 1:
            buttonText = "Results"
        case 2:
            buttonText = "Finish"
        default:
            buttonText = "Next"
        }
        if state < 3 {
            state += 1
        }
    }
    
    func fetchQuizes() {
        AF.request("http://192.168.21.8:3069/quiz").response { response in
            switch response.result {
            case .success:
                // Sukces - obraz został wysłany do API
                do {
                    let json = try JSONDecoder().decode(GetQuizzesResponse.self, from: response.data!)
                    self.quizzes = json.quizzes
                    self.selectedQuiz = json.quizzes[0].name
                } catch {
                    
                }

            case .failure(let error):
                print("Error while fetching quizzes", error)
            }}
    }
    
    func upload(images: [UIImage]) {
        var resultImages: [Data] = []
        
        let quizId = self.quizzes.filter { $0.name == self.selectedQuiz}[0].id
        
        // Konwertuj obraz na dane binarne w formacie JPEG lub PNG
        for image in images {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                resultImages.append(imageData)
            } else {
                let error = NSError(domain: "ImageConversionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Błąd konwersji obrazu"])
                print("ERROR WHILE CONVERTING", error)
                return
            }
        }
        
        let apiURL = URL(string: "http://192.168.21.8:3069/quiz/submit")!
        
        // Nagłówki żądania, jeśli są potrzebne
        let headers: HTTPHeaders = []
        
        // Parametry żądania, jeśli są potrzebne
        let parameters: Parameters = [
            "quizId": quizId
        ]
        
        // Wysyłamy żądanie POST z danymi obrazu
        AF.upload(multipartFormData: { multipartFormData in
            var idx = 0;
            for img in resultImages {
                multipartFormData.append(img, withName: "files", fileName: String(idx) + ".png", mimeType: "image/png")
                idx += 1
            }
            
            
            for (key, value) in parameters {
                multipartFormData.append(Data("\(value)".data(using: .utf8)!), withName: key)
            }
        }, to: apiURL, method: .post, headers: headers)
        .response { response in
            switch response.result {
            case .success:
                // Sukces - obraz został wysłany do API
                do {
                    let json = try JSONDecoder().decode(UploadImagesResponse.self, from: response.data!)
                    for result in json.results {
                        self.results.append(UserResult(name: result.name, score: result.score))
                    }

                    self.showAlert = true;
                } catch {
                    print("Unexpected error: \(error).")
                }
      
                
            
            case .failure(let error):
                // Błąd podczas wysyłania obrazu
                print("ERROR WHILE SENDING IMAGE", error)
            }
        }
  
        
        
    }
    
    
}


#Preview {
    ContentView()
}
