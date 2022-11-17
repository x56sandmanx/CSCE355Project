#include <iostream>
#include <fstream>
#include <sstream>
#include<vector>
using namespace std;

int main(int argc, char *argv[])
{
    //Variables for inputString, Vec, states and symbols
    vector<char> inputStringVec;
    string line, inputString, currState, nextState, slash, nextCurrState, highestState, trash;
    char currSym, nextSym, move;

    //Check to make sure input file is in
    if(argc <= 1)
    {
        cout<<"Please input text file to read"<<"\n";
        return 0;
    }

    //Start of program
    while(true)
    {
        //Create a file with the input file
        ifstream myFile(argv[1]);

        //Getting the first line in the file to see the highest state in the certain TM
        getline(myFile, highestState);

        /*Create a stringstream with trash varibales in order to get to the highestState,
        /so we know what the highest state is for accepting/rejecting*/
        stringstream st(highestState);
        st >> trash >> trash >> trash >> trash >> highestState;

        //We now ignore the next line in order for our loop to start at the first state in the file
        myFile.ignore(256, '\n');

        //Get user input
        getline(cin,inputString);

        //If the user just hits enter, we set it to a blank input
        if(inputString == "")
            inputString = "_";
        
        //If the user hits cntrl D, we end the program
        if(cin.eof())
        {
            return 0;
        }

        //This is to initalize our vector and pointer
        inputStringVec.clear();
        int pointer = 0;
        bool accepted = false;
        nextCurrState = '0';

        //Convert input string to vector
        for(int i=0;i<inputString.size();i++)
        {
            inputStringVec.push_back(inputString[i]);
        }

        //This is the start of our looping through states/input
        while(!accepted)
        {
            //Start looping through transitions
            while(getline(myFile, line))
            {
                //Create a stringstream with the line to set all our variables with the states and symbols
                stringstream ss(line);
                ss >> currState >> currSym >> slash >> nextState >> nextSym >> move;
    
                //If our currSym equals the pointers symbol, and the currState equals the nextCurrState, we match
                if(currSym == inputStringVec[pointer] && currState == nextCurrState)
                {
                    //Inserting () for output on pointer to show where we are
                    inputStringVec.insert(inputStringVec.begin() + pointer, '(');
                    inputStringVec.insert(inputStringVec.begin() + pointer + 2, ')');

                    //If the state is < than 10, we leave a space for grading purposes
                    if(stoi(currState) < 10)
                        cout<<" "<<currState<<":";
                    else
                        cout<<currState<<":";
                    
                    //Print out the StringVec
                    for(int i=0;i<inputStringVec.size();i++)
                    {
                        cout<<inputStringVec[i];
                    }
                    cout<<endl;

                    //Remove the ()
                    inputStringVec.erase(inputStringVec.begin()+pointer);
                    inputStringVec.erase(inputStringVec.begin()+pointer+1);
  
                    //Change the curr symbol on pointer to the next one
                    inputStringVec[pointer] = nextSym;
                    
                    //Set the nextCurrState to the nextState, for the if statement
                    nextCurrState = nextState;

                    //Now move based on the move symbol
                    if(move == '<')
                    {
                        //For both > and <, if we move and there was a blank, we just need to remove it
                        if(inputStringVec[pointer] == '_')
                        {
                            inputStringVec.erase(inputStringVec.begin()+pointer);
                        }
                        pointer--;
                    }
                    
                    if(move == '>')
                    {
                        if(inputStringVec[pointer] == '_')
                        {
                            inputStringVec.erase(inputStringVec.begin());
                            pointer = 0;
                        }
                        else
                            pointer++;
                    }

                    //If out pointer goes out of bounds either negative, or bigger than the size, we need to add a blank
                    //and reset the pointer based on where in the vec we set that blank
                    if(pointer < 0)
                    {
                        inputStringVec.insert(inputStringVec.begin(), '_');
                        pointer = 0;
                    }
                    if(pointer > inputStringVec.size()-1)
                    {
                        inputStringVec.insert(inputStringVec.end(), '_');
                        pointer = inputStringVec.size()-1;
                    }
                    if(inputStringVec.empty())
                    {
                        inputStringVec.insert(inputStringVec.begin(), '_');
                        pointer = 0;
                    }

                    //Finally we have finished the transition, so we go back to the top of the file and ignore the first
                    //two lines in roder to start at the first transitions and repeat this process
                    myFile.seekg(0);
                    myFile.ignore(256, '\n');
                    myFile.ignore(256, '\n');
                }
            }

            //Once the transitions are done, we print out our final transition state
            inputStringVec.insert(inputStringVec.begin() + pointer, '(');
            inputStringVec.insert(inputStringVec.begin() + pointer + 2, ')');

            //For grading, if the state is < than 10, put a space in front to align
            if(stoi(nextCurrState) < 10)
                cout<<" "<<nextCurrState<<":";
            else
                cout<<nextCurrState<<":";
            
            //Print out our transition state
            for(int i=0;i<inputStringVec.size();i++)
            {
                cout<<inputStringVec[i];
            }
            cout<<endl;

            //If the highestState was the final state, we have accepted the string, otherwise reject it
            if(highestState == nextCurrState)
            {
                cout<<"accept"<<endl;
            }
            else
            {
                cout<<"reject"<<endl;
            }
            
            accepted = true;
        }
    }
}