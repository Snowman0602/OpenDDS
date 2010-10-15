#ifndef DELEGATE_H
#define DELEGATE_H

// Needed here to avoid the pragma below when necessary.
#include /**/ "ace/pre.h"
#include /**/ "ace/config-all.h"

#if !defined (ACE_LACKS_PRAGMA_ONCE)
#pragma once
#endif /* ACE_LACKS_PRAGMA_ONCE */

#include "model_export.h"
#include "CopyQos.h"

namespace DDS {
  class DomainParticipant;
  class Topic;
  class Publisher;
  class Subscriber;
  class DataWriter;
  class DataReader;
} // End of namespace DDS

namespace OpenDDS { namespace DCPS {
  class TransportConfiguration;
  class TransportImpl;
} } // End of namespace OpenDDS::DCPS

namespace OpenDDS { namespace Model {

  class OpenDDS_Model_Export Delegate {
    public:
      Delegate();

      void init( int argc, char** argv);
      void fini();

      DDS::DomainParticipant*
      createParticipant(
        unsigned long             domain,
        DDS::DomainParticipantQos participantQos,
        DDS::StatusMask           mask
      );

      DDS::Topic*
      createTopic(
        DDS::DomainParticipant* participant,
        const std::string&      topicName,
        const std::string&      typeName,
        DDS::TopicQos           topicQos,
        DDS::StatusMask         mask
      );

      DDS::Publisher*
      createPublisher(
        DDS::DomainParticipant*       participant,
        DDS::PublisherQos             publisherQos,
        DDS::StatusMask               mask,
        OpenDDS::DCPS::TransportImpl* transport
      );

      DDS::Subscriber*
      createSubscriber(
        DDS::DomainParticipant*       participant,
        DDS::SubscriberQos            subscriberQos,
        DDS::StatusMask               mask,
        OpenDDS::DCPS::TransportImpl* transport
      );

      DDS::DataWriter*
      createPublication(
        unsigned int       which,
        DDS::Publisher*    publisher,
        DDS::Topic*        topic,
        DDS::DataWriterQos writerQos,
        DDS::StatusMask    mask
      );

      DDS::DataReader*
      createSubscription(
        unsigned int       which,
        DDS::Subscriber*   subscriber,
        DDS::Topic*        topic,
        DDS::DataReaderQos readerQos,
        DDS::StatusMask    mask
      );

      OpenDDS::DCPS::TransportImpl*
      createTransport(
        unsigned long                          key,
        const char*                            kind,
        OpenDDS::DCPS::TransportConfiguration* config
      );

      CopyQos*& service();

    private:
      CopyQos* service_;
  };

} } // End of namespace OpenDDS::Model

#include /**/ "ace/post.h"

#endif /* DELEGATE_H */

