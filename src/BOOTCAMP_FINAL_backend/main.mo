import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Result "mo:base/Result";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Http "http";
actor {

  func _getWebpage() : Text {
    var webpage = "<style>" #
    "body { text-align: center; font-family: Arial, sans-serif; background-color: #f0f8ff; color: #333; }" #
    "h1 { font-size: 3em; margin-bottom: 10px; }" #
    "hr { margin-top: 20px; margin-bottom: 20px; }" #
    "em { font-style: italic; display: block; margin-bottom: 20px; }" #
    "ul { list-style-type: none; padding: 0; }" #
    "li { margin: 10px 0; }" #
    "li:before { content: '👉 '; }" #
    "svg { max-width: 150px; height: auto; display: block; margin: 20px auto; }" #
    "h2 { text-decoration: underline; }" #
    "</style>";

    webpage := webpage # "<div><h1>" # name # "</h1></div>";
    for (proposal in proposals.vals()) {
      if (proposal.status == #Accepted) {
        manifesto := proposal.newText;
      };
    };
    webpage := webpage # "<em>" # manifesto # "</em>";
    webpage := webpage # "<div>" # logo # "</div>";
    webpage := webpage # "<hr>";
    webpage := webpage # "<h2>Open Proposals:</h2>";
    webpage := webpage # "<ul>";
    for (proposal in proposals.vals()) {
      if (proposal.status == #Open) {
        webpage := webpage # "<li>" # proposal.newText # "</li>";
      };
    };
    webpage := webpage # "</ul>";
    return webpage;
  };

  let name : Text = "Vote To Change";
  var manifesto : Text = "This is the Original Text";
  let logo : Text = "<?xml version='1.0' encoding='UTF-8'?>
<svg xmlns='http://www.w3.org/2000/svg' id='Layer_1' data-name='Layer 1' viewBox='0 0 24 24'>
  <path d='m20,14v2l-1.5,8h-9.5v-8h-2v8h-1c-1.105,0-2-.895-2-2v-6c0-1.105.895-2,2-2h3.026l2.193-4.149c.18-.352.428-.614.682-.719.212-.088.427-.132.64-.132.682,0,1.244.446,1.432,1.136.022.08.05.265-.007.599l-.58,3.265h6.613Zm-7.989-7.762l2.173,1.68.504-.349-.884-2.686,2.197-1.273v-.611h-2.883l-.784-3h-.648l-.784,3h-2.899v.615l2.212,1.231-.869,2.717.48.362,2.183-1.687Zm-8.001,3l2.173,1.68.504-.349-.884-2.686,2.197-1.273v-.611h-2.883l-.784-3h-.648l-.784,3H.003v.615l2.212,1.231-.869,2.717.48.362,2.183-1.687Zm16,0l2.173,1.68.504-.349-.884-2.686,2.197-1.273v-.611h-2.883l-.784-3h-.648l-.784,3h-2.899v.615l2.212,1.231-.869,2.717.48.362,2.183-1.687Z'/>
</svg>";

  public type Member = {
    name : Text;
    age : Nat;
  };
  public type Result<A, B> = Result.Result<A, B>;
  public type HashMap<A, B> = HashMap.HashMap<A, B>;

  let dao : HashMap<Principal, Member> = HashMap.HashMap<Principal, Member>(0, Principal.equal, Principal.hash);

  public shared ({ caller }) func addMember(member : Member) : async Result<(), Text> {
    switch (dao.get(caller)) {
      case (?member) {
        return #err("Already a member");
      };
      case (null) {
        dao.put(caller, member);
        return #ok(());
      };
    };
  };

  public shared ({ caller }) func removeMember() : async Result<(), Text> {
    switch (dao.get(caller)) {
      case (?member) {
        dao.delete(caller);
        return #ok(());
      };
      case (null) {
        return #err("Not a member");
      };
    };
  };

  public query func getMember(p : Principal) : async Result<Member, Text> {
    switch (dao.get(p)) {
      case (?member) {
        return #ok(member);
      };
      case (null) {
        return #err("Not a member");
      };
    };
  };

  public query func getAllMembers() : async [Member] {
    return Iter.toArray(dao.vals());
  };

  public query func numberOfMembers() : async Nat {
    return dao.size();
  };

  public type Status = {
    #Open;
    #Accepted;
    #Rejected;
    #Implemented;
  };

  public type Proposal = {
    id : Int;
    status : Status;
    newText : Text;
  };

  public type VoteOk = {
    #ProposalAccepted;
    #ProposalRefused;
    #ProposalOpen;
  };

  var nextProposalId : Int = 0;
  let proposals = TrieMap.TrieMap<Int, Proposal>(Int.equal, Int.hash);

  public shared ({ caller }) func submitProposal(text : Text) : async {
    #Ok : Proposal;
    #Err : Text;
  } {
    switch (dao.get(caller)) {
      case (null) { return #Err("Not DAO Member") };
      case (?member) {
        nextProposalId += 1;
        let newProposal = {
          id = nextProposalId;
          status = #Open;
          newText = text;
        };
        proposals.put(nextProposalId, newProposal);
        return #Ok(newProposal);
      };
    };
  };

  public shared ({ caller }) func vote(proposalId : Int, yesOrNo : Bool) : async {
    #Ok : VoteOk;
    #Err : Text;
  } {
    switch (dao.get(caller)) {
      case (null) { return #Err("Only Members can Vote !!") };
      case (?member) {
        var voteok : VoteOk = #ProposalOpen;
        switch (proposals.get(proposalId)) {
          case (null) { return #Err("Proposal Not Found") };
          case (?proposal) {
            switch (proposal.status) {
              case (#Open) {
                var newstatus : Status = #Open;
                switch (yesOrNo) {
                  case (false) {
                    newstatus := #Rejected;
                    voteok := #ProposalRefused;
                  };
                  case (true) {
                    newstatus := #Accepted;
                    voteok := #ProposalAccepted;
                    label checkImplemented for ((id, proposal) in proposals.entries()) {
                      if (proposal.status == #Accepted) {
                        let newProposal = {
                          id = id;
                          status = #Implemented;
                          newText = proposal.newText;
                        };
                        proposals.put(id, newProposal);
                        break checkImplemented;
                      };
                    };
                  };
                };
                let newProposal = {
                  id = proposalId;
                  status = newstatus;
                  newText = proposal.newText;
                };
                proposals.put(proposalId, newProposal);
                return (#Ok(voteok));
              };
              case (#Accepted) {
                return #Err("Proposal Already Accepted");
              };
              case (#Rejected) {
                return #Err("Proposal Already Refused");
              };
              case (#Implemented) {
                return #Err("Proposal Already Implemented");
              };
            };
          };
        };
      };
    };
  };

  public query func getProposal(id : Int) : async ?Proposal {
    switch (proposals.get(id)) {
      case (null) { return null };
      case (?proposal) { return ?proposal };
    };
  };

  public query func getAllProposals() : async [(Int, Proposal)] {
    return Iter.toArray(proposals.entries());
  };

  public shared query ({ caller }) func whoami() : async Principal {
    return caller;
  };

  // Webpage
  public type HttpRequest = Http.Request;
  public type HttpResponse = Http.Response;
  public query func http_request(request : HttpRequest) : async HttpResponse {
    return ({
      body = Text.encodeUtf8(_getWebpage());
      headers = [("Content-Type", "text/html; charset=UTF-8")];
      status_code = 200 : Nat16;
      streaming_strategy = null;
    });
  };
};
